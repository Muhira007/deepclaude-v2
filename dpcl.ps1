# dpcl — run Claude Code against DeepSeek's Anthropic-compatible API (Windows).
#
# Key resolution order:
#   1. `dpcl config [KEY]`  — set/replace the stored key (inline or prompt)
#   2. stored config file         — set on a previous run
#   3. $env:DEEPSEEK_API_KEY      — used and saved for next time
#   4. interactive prompt         — asks for the key if you haven't included it yet

$ErrorActionPreference = 'Stop'

$Script:Version      = '1.0.0'
$Script:ConfigDir    = Join-Path $env:APPDATA 'dpcl'
$Script:ConfigFile   = Join-Path $Script:ConfigDir 'config'

# --- defaults ----------------------------------------------------------------
$Script:DefaultModel       = 'deepseek-v4-pro[1m]'
$Script:DefaultHaikuModel  = 'deepseek-v4-flash'
$Script:DefaultSubagent    = 'deepseek-v4-flash'
$Script:DefaultEffort      = 'max'

# --- helpers -----------------------------------------------------------------
function Write-Say   { param([string]$Msg) Write-Host $Msg }
function Write-Warn  { param([string]$Msg) Write-Host "WARNING: $Msg" -ForegroundColor Yellow }
function Write-ErrorX { param([string]$Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red; exit 1 }
function Write-DebugX {
  param([string]$Msg)
  if ($env:DPCL_VERBOSE -eq '1') { Write-Host "[DEBUG] $Msg" -ForegroundColor DarkGray }
}

# --- config file I/O ---------------------------------------------------------
function Read-Config {
  param([string]$Key)
  if (-not (Test-Path $Script:ConfigFile)) { return $null }
  foreach ($line in Get-Content $Script:ConfigFile) {
    if ($line -match "^\s*${Key}=(.*)$") { return $Matches[1] }
  }
  return $null
}

function Write-Config {
  param([string]$Key, [string]$Value)
  New-Item -ItemType Directory -Force -Path $Script:ConfigDir | Out-Null
  $lines = @()
  $found = $false
  if (Test-Path $Script:ConfigFile) {
    foreach ($line in Get-Content $Script:ConfigFile) {
      if ($line -match "^\s*${Key}=") {
        $lines += "${Key}=${Value}"
        $found = $true
      } else {
        $lines += $line
      }
    }
  }
  if (-not $found) { $lines += "${Key}=${Value}" }
  Set-Content -Path $Script:ConfigFile -Value $lines -Encoding ASCII
  # Restrict to current user
  try {
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      "$env:USERDOMAIN\$env:USERNAME", 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $Script:ConfigFile -AclObject $acl
  } catch {
    Write-DebugX "Set-Acl failed (non-NTFS drive?): $_"
  }
}

function Save-Key {
  param([string]$Key)
  $Key = $Key.Trim()
  if ([string]::IsNullOrEmpty($Key)) {
    Write-ErrorX 'Refusing to save an empty key.'
  }
  if (-not (Test-KeyFormat $Key)) {
    Write-Warn "Key format looks unusual (expected 'sk-...' prefix)."
    Write-Warn 'Saving anyway, but it may not work.'
  }
  Write-Config 'DEEPSEEK_API_KEY' $Key
  Write-Say "Key saved to $Script:ConfigFile"
}

function Get-Key {
  return Read-Config 'DEEPSEEK_API_KEY'
}

# --- key validation ----------------------------------------------------------
function Test-KeyFormat {
  param([string]$Key)
  return ($Key -match '^sk-[a-zA-Z0-9]+')
}

function Test-KeyApi {
  param([string]$Key)
  Write-Say 'Verifying API key...'
  try {
    $resp = Invoke-WebRequest -Uri 'https://api.deepseek.com/v1/models' `
      -Headers @{ Authorization = "Bearer $Key" } `
      -Method Get `
      -TimeoutSec 10 `
      -ErrorAction Stop
    if ($resp.StatusCode -eq 200) {
      Write-Say '[v] API key is valid.'
      return $true
    }
  } catch {
    if ($_.Exception -and $_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
      if ($statusCode -eq 401) {
        Write-Warn '[x] API key is invalid or expired (HTTP 401).'
        return $false
      } elseif ($statusCode -eq 403) {
        Write-Warn '[x] API key lacks permissions (HTTP 403).'
        return $false
      } else {
        Write-Warn "Unexpected response (HTTP $statusCode). Key may still work."
        return $true
      }
    } else {
      Write-Warn 'Could not reach DeepSeek API (network error).'
      return $true
    }
  }
  return $true
}

# --- interactive setup -------------------------------------------------------
function Invoke-Setup {
  Write-Say ''
  Write-Say '+------------------------------------------+'
  Write-Say '|  dpcl - first-time setup           |'
  Write-Say '+------------------------------------------+'
  Write-Say ''
  Write-Say "Claude Code will run against DeepSeek's API."
  Write-Say 'You only need to enter your key once.'
  Write-Say 'Get a key: https://platform.deepseek.com/api_keys'
  Write-Say ''
  for ($i = 0; $i -lt 3; $i++) {
    $secure = Read-Host -AsSecureString 'DeepSeek API key'
    $bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $key    = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $key = $key.Trim()
    if ($key) {
      if (-not (Test-KeyFormat $key)) {
        Write-Warn "Key should start with 'sk-'. Please double-check."
      }
      Save-Key $key
      Write-Say ''
      Write-Say 'Key saved. Verifying...'
      Test-KeyApi $key | Out-Null
      return
    }
    Write-Say "Key can't be empty."
  }
  Write-ErrorX 'Aborting after 3 empty attempts.'
}

# --- help --------------------------------------------------------------------
function Show-Help {
@'
dpcl — run Claude Code against DeepSeek's Anthropic-compatible API.

USAGE
  dpcl [FLAGS] [--] [ARGUMENTS...]

FLAGS
  --help, help       Show this help message
  --version          Show version number
  --dry-run          Print what would be executed, without running Claude Code
  --verbose          Print debug information during execution
  --safe             Run WITHOUT --dangerously-skip-permissions (more prompts)

SUBCOMMANDS
  dpcl config [KEY]       Set or change the stored API key
  dpcl change-key [KEY]   Alias for config
  dpcl reset              Delete the stored API key
  dpcl update             Update to the latest version
  dpcl verify             Verify the stored API key against DeepSeek API
  dpcl show-config        Print current configuration (key masked)

KEY RESOLUTION ORDER
  1. dpcl config <KEY>
  2. Stored config file (%APPDATA%\dpcl\config)
  3. DEEPSEEK_API_KEY environment variable (auto-saved on use)
  4. Interactive prompt

ENVIRONMENT VARIABLES
  DEEPSEEK_API_KEY              DeepSeek API key (saved automatically on first use)
  DPCL_SAFE=1             Same as --safe
  DPCL_VERBOSE=1          Same as --verbose
  DPCL_MODEL              Default model (default: deepseek-v4-pro[1m])
  DPCL_HAIKU_MODEL        Haiku/flash model (default: deepseek-v4-flash)
  DPCL_SUBAGENT_MODEL     Subagent model (default: deepseek-v4-flash)
  DPCL_EFFORT             Effort level (default: max)

CONFIG FILE
  Path:  %APPDATA%\dpcl\config
  Format: KEY=VALUE (one per line)

EXAMPLES
  dpcl                              # First run: enter key, then start
  dpcl "refactor this module"       # Pass a prompt to Claude Code
  dpcl --safe "rm -rf ./build"      # Run with permission prompts enabled
  dpcl --dry-run --verbose          # Preview what will be set
  dpcl config sk-xxx                # Set key without interactive prompt
  dpcl verify                       # Check if your stored key works
  dpcl show-config                  # See current settings
  $env:DPCL_MODEL='other'; dpcl  # Override model for one session
'@
  exit 0
}

# --- show config -------------------------------------------------------------
function Show-Config {
  $key = Get-Key
  $savedSafe = if ($val = Read-Config 'DPCL_SAFE') { $val } else { '0' }

  Write-Host "Config file : $Script:ConfigFile"
  Write-Host "Config dir  : $Script:ConfigDir"
  Write-Host '---'
  if ($key) { Write-Host "API key     : (stored, $($key.Length) chars)" } else { Write-Host 'API key     : (not set)' }
  Write-Host "Safe mode   : $(if ($env:DPCL_SAFE) { $env:DPCL_SAFE } else { $savedSafe })"
  Write-Host '---'
  Write-Host 'Model overrides (from config or env):'
  $model    = if ($env:DPCL_MODEL)        { $env:DPCL_MODEL }        else { $v = Read-Config 'DPCL_MODEL';        if ($v) { $v } else { $Script:DefaultModel } }
  $haiku    = if ($env:DPCL_HAIKU_MODEL)   { $env:DPCL_HAIKU_MODEL }   else { $v = Read-Config 'DPCL_HAIKU_MODEL';   if ($v) { $v } else { $Script:DefaultHaikuModel } }
  $subagent = if ($env:DPCL_SUBAGENT_MODEL){ $env:DPCL_SUBAGENT_MODEL} else { $v = Read-Config 'DPCL_SUBAGENT_MODEL'; if ($v) { $v } else { $Script:DefaultSubagent } }
  $effort   = if ($env:DPCL_EFFORT)        { $env:DPCL_EFFORT }        else { $v = Read-Config 'DPCL_EFFORT';        if ($v) { $v } else { $Script:DefaultEffort } }

  Write-Host "  MODEL        : $model"
  Write-Host "  HAIKU_MODEL  : $haiku"
  Write-Host "  SUBAGENT     : $subagent"
  Write-Host "  EFFORT       : $effort"
  exit 0
}

# --- dry run -----------------------------------------------------------------
function Invoke-DryRun {
  param([array]$RemainingArgs)
  $key      = Get-Key
  $safeMode = if ($env:DPCL_SAFE) { $env:DPCL_SAFE } else { $v = Read-Config 'DPCL_SAFE'; if ($v) { $v } else { '0' } }
  $model    = if ($env:DPCL_MODEL)        { $env:DPCL_MODEL }        else { $v = Read-Config 'DPCL_MODEL';        if ($v) { $v } else { $Script:DefaultModel } }
  $haiku    = if ($env:DPCL_HAIKU_MODEL)   { $env:DPCL_HAIKU_MODEL }   else { $v = Read-Config 'DPCL_HAIKU_MODEL';   if ($v) { $v } else { $Script:DefaultHaikuModel } }
  $subagent = if ($env:DPCL_SUBAGENT_MODEL){ $env:DPCL_SUBAGENT_MODEL} else { $v = Read-Config 'DPCL_SUBAGENT_MODEL'; if ($v) { $v } else { $Script:DefaultSubagent } }
  $effort   = if ($env:DPCL_EFFORT)        { $env:DPCL_EFFORT }        else { $v = Read-Config 'DPCL_EFFORT';        if ($v) { $v } else { $Script:DefaultEffort } }

  Write-Host '═══════════════════════════════════════════════'
  Write-Host '  dpcl dry-run'
  Write-Host '═══════════════════════════════════════════════'
  Write-Host ''
  Write-Host 'Would set these environment variables:'
  Write-Host ''
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_BASE_URL', 'https://api.deepseek.com/anthropic')
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_AUTH_TOKEN', $(if ($key) { "(hidden, $($key.Length) chars)" } else { '(not set)' }))
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_MODEL', $model)
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_OPUS_MODEL', $model)
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_SONNET_MODEL', $model)
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_HAIKU_MODEL', $haiku)
  Write-Host ('  {0,-36} {1}' -f 'CLAUDE_CODE_SUBAGENT_MODEL', $subagent)
  Write-Host ('  {0,-36} {1}' -f 'CLAUDE_CODE_EFFORT_LEVEL', $effort)
  Write-Host ''
  if ($safeMode -eq '1') {
    Write-Host "Would run: claude $($RemainingArgs -join ' ')"
  } else {
    Write-Host "Would run: claude --dangerously-skip-permissions $($RemainingArgs -join ' ')"
  }
  Write-Host ''
  if ($safeMode -ne '1') {
    Write-Host '⚠  --dangerously-skip-permissions is ENABLED (use --safe to disable)'
  } else {
    Write-Host '[v]  Safe mode: tools will require per-action approval'
  }
  exit 0
}

# --- subcommand handler ------------------------------------------------------
function Invoke-Subcommand {
  param([string]$Cmd, [array]$SubArgs)

  if ($Cmd -match '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key)$') {
    if ($SubArgs.Count -ge 1) { Save-Key $SubArgs[0] } else { Invoke-Setup }
    Write-Say "Done. Run 'dpcl' to start."
    exit 0
  } elseif ($Cmd -match '^(reset|--reset)$') {
    if (Test-Path $Script:ConfigFile) {
      Remove-Item $Script:ConfigFile -Force
      Write-Say "Stored key removed ($Script:ConfigFile)."
    } else {
      Write-Say 'No stored key to remove.'
    }
    exit 0
  } elseif ($Cmd -match '^(update|--update|upgrade|--upgrade)$') {
    Write-Say 'Updating dpcl to the latest version...'
    irm 'https://raw.githubusercontent.com/Muhira007/deepclaude-v2/main/install.ps1' | iex
    exit 0
  } elseif ($Cmd -match '^(verify|--verify)$') {
    $key = Get-Key
    if (-not $key) { Write-ErrorX "No stored key. Run 'dpcl config' first." }
    Write-Say "Stored key: $($key.Substring(0, [Math]::Min(5, $key.Length)))...$($key.Substring($key.Length - [Math]::Min(4, $key.Length))) ($($key.Length) chars)"
    if (Test-KeyFormat $key) {
      Write-Say 'Format:  [v] (starts with sk-)'
    } else {
      Write-Warn 'Format:  [x] (expected sk-... prefix)'
    }
    Test-KeyApi $key | Out-Null
    exit 0
  } elseif ($Cmd -match '^(doctor)$') {
    Write-Say "--- dpcl Doctor ---"
    $healthy = $true
    
    # Node.js check
    if (Get-Command node -ErrorAction SilentlyContinue) {
      $nodeVer = (node -v).Trim()
      Write-Say "[v] Node.js installed ($nodeVer)"
    } else {
      Write-Warn "[x] Node.js not found. Claude Code requires Node.js."
      $healthy = $false
    }
    
    # npm check
    if (Get-Command npm -ErrorAction SilentlyContinue) {
      $npmVer = (npm -v).Trim()
      Write-Say "[v] npm installed ($npmVer)"
    } else {
      Write-Warn "[x] npm not found."
      $healthy = $false
    }
    
    # claude check
    if (Get-Command claude -ErrorAction SilentlyContinue) {
      $claudeVer = (claude --version).Trim()
      Write-Say "[v] Claude Code installed ($claudeVer)"
    } else {
      Write-Warn "[x] Claude Code not found. Will prompt for auto-install on launch."
      $healthy = $false
    }
    
    # API Key
    $key = Get-Key
    if ($key) {
      Write-Say "[v] API Key is configured."
      if (Test-KeyApi $key) {
        Write-Say "[v] API Key can reach DeepSeek servers successfully."
      } else {
        Write-Warn "[x] API Key failed validation."
        $healthy = $false
      }
    } else {
      Write-Warn "[x] No API Key set. Run 'dpcl config'."
      $healthy = $false
    }
    
    if ($healthy) {
      Write-Say "`nSystem is fully ready to use dpcl!"
    } else {
      Write-Warn "`nSome checks failed. Please fix the warnings above."
    }
    exit 0
  } elseif ($Cmd -match '^(clean)$') {
    Write-Say "Clearing Claude Code memory/cache..."
    $localClaude = Join-Path (Get-Location) ".claude"
    if (Test-Path $localClaude) {
      Remove-Item -Recurse -Force $localClaude
      Write-Say "[v] Removed local project memory ($localClaude)"
    } else {
      Write-Say "[v] No local project memory found."
    }
    exit 0
  } elseif ($Cmd -match '^(alias)$') {
    $aliasName = 'c'
    if ($SubArgs.Count -gt 0) { $aliasName = $SubArgs[0] }
    if (-not (Test-Path $PROFILE)) {
      New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    $aliasCmd = "Set-Alias $aliasName dpcl"
    Add-Content -Path $PROFILE -Value "`n# Added by dpcl`n$aliasCmd"
    Write-Say "[v] Alias '$aliasName' for 'dpcl' has been added to your PowerShell profile ($PROFILE)."
    Write-Say "Restart your terminal or run . '$PROFILE' to use it."
    exit 0
  } elseif ($Cmd -match '^(show-config|--show-config|show|--show)$') {
    Show-Config
  } elseif ($Cmd -match '^(help|--help|-h)$') {
    Show-Help
  }
}# ============================================================================
# MAIN
# ============================================================================

# Separate dpcl flags from passthrough args
$dryRun      = $false
$passthrough = [System.Collections.ArrayList]::new()
$i           = 0

while ($i -lt $args.Count) {
  switch ($args[$i]) {
    '--help'    { Show-Help }
    'help'      { Show-Help }
    '-h'        { Show-Help }
    '--version' { Write-Host "dpcl v$Script:Version"; exit 0 }
    '--dry-run' { $dryRun = $true; $i++ }
    '--verbose' { $env:DPCL_VERBOSE = '1'; $i++ }
    '--safe'    { $env:DPCL_SAFE = '1'; $i++ }
    '--'        { $i++; for (; $i -lt $args.Count; $i++) { $passthrough.Add($args[$i]) | Out-Null }; break }
    default {
      # Check if this is a subcommand
      if ($args[$i] -match '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key|reset|--reset|update|--update|upgrade|--upgrade|verify|--verify|doctor|clean|alias|show-config|--show-config|show|--show)$') {
        $subArgs = @()
        for ($j = $i + 1; $j -lt $args.Count; $j++) { $subArgs += $args[$j] }
        Invoke-Subcommand -Cmd $args[$i] -SubArgs $subArgs
      }
      $passthrough.Add($args[$i]) | Out-Null
      $i++
    }
  }
}

Write-DebugX "dpcl v$Script:Version starting"
Write-DebugX "CONFIG_FILE=$Script:ConfigFile"
Write-DebugX "DRY_RUN=$dryRun"
Write-DebugX "DPCL_SAFE=$(if ($env:DPCL_SAFE) { $env:DPCL_SAFE } else { '0' })"
Write-DebugX "DPCL_VERBOSE=$(if ($env:DPCL_VERBOSE) { $env:DPCL_VERBOSE } else { '0' })"

# --- resolve the key ---------------------------------------------------------
$key = Get-Key
Write-DebugX "Key from config: $(if ($key) { "found ($($key.Length) chars)" } else { 'not found' })"

if (-not $key -and $env:DEEPSEEK_API_KEY) {
  $key = $env:DEEPSEEK_API_KEY.Trim()
  Write-Say 'Using DEEPSEEK_API_KEY from environment; saving for next time.'
  try {
    Save-Key $key
  } catch {
    Write-Warn "Could not save key to $Script:ConfigFile (disk full or permission issue?)."
    Write-Warn 'Key will only be used for this session.'
  }
}

if (-not $key) {
  Invoke-Setup
  $key = Get-Key
}

if (-not $key) {
  Write-ErrorX "No API key available. Run 'dpcl config' to set one."
}

Write-DebugX "Key resolved ($($key.Length) chars)"

# --- resolve model overrides -------------------------------------------------
$model    = if ($env:DPCL_MODEL)         { $env:DPCL_MODEL }         else { $v = Read-Config 'DPCL_MODEL';         if ($v) { $v } else { $Script:DefaultModel } }
$haiku    = if ($env:DPCL_HAIKU_MODEL)    { $env:DPCL_HAIKU_MODEL }    else { $v = Read-Config 'DPCL_HAIKU_MODEL';    if ($v) { $v } else { $Script:DefaultHaikuModel } }
$subagent = if ($env:DPCL_SUBAGENT_MODEL) { $env:DPCL_SUBAGENT_MODEL } else { $v = Read-Config 'DPCL_SUBAGENT_MODEL'; if ($v) { $v } else { $Script:DefaultSubagent } }
$effort   = if ($env:DPCL_EFFORT)         { $env:DPCL_EFFORT }         else { $v = Read-Config 'DPCL_EFFORT';         if ($v) { $v } else { $Script:DefaultEffort } }
$safeMode = if ($env:DPCL_SAFE)           { $env:DPCL_SAFE }           else { $v = Read-Config 'DPCL_SAFE';           if ($v) { $v } else { '0' } }

Write-DebugX "MODEL=$model"
Write-DebugX "HAIKU_MODEL=$haiku"
Write-DebugX "SUBAGENT_MODEL=$subagent"
Write-DebugX "EFFORT=$effort"
Write-DebugX "SAFE_MODE=$safeMode"

# --- dry-run early exit ------------------------------------------------------
if ($dryRun) {
  Invoke-DryRun -RemainingArgs $passthrough.ToArray()
}

# --- launch ------------------------------------------------------------------
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-ErrorX "claude CLI not found on PATH.`nInstall Claude Code first: https://docs.claude.com/en/docs/claude-code"
}

$env:ANTHROPIC_BASE_URL            = 'https://api.deepseek.com/anthropic'
$env:ANTHROPIC_AUTH_TOKEN          = $key
$env:ANTHROPIC_MODEL               = $model
$env:ANTHROPIC_DEFAULT_OPUS_MODEL  = $model
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $haiku
$env:CLAUDE_CODE_SUBAGENT_MODEL    = $subagent
$env:CLAUDE_CODE_EFFORT_LEVEL      = $effort

Write-DebugX 'Environment variables set. Launching claude...'

if ($safeMode -eq '1') {
  Write-Say 'Running in safe mode (permission prompts enabled).'
  & claude @passthrough
} else {
  & claude --dangerously-skip-permissions @passthrough
}
exit $LASTEXITCODE

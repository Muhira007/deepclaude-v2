# deepclaude installer for Windows (PowerShell).
# Usage:
#   irm https://raw.githubusercontent.com/RafiulM/deepclaude/main/install.ps1 | iex
#
# Options:
#   $env:VERSION = 'v1.0.0'; irm ... | iex   # Pin a version
#

$ErrorActionPreference = 'Stop'

$Version = if ($env:VERSION) { $env:VERSION } else { 'main' }
$Repo    = "https://raw.githubusercontent.com/RafiulM/deepclaude/$Version"
$Dest    = Join-Path $env:LOCALAPPDATA 'Programs\deepclaude'

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

Write-Host "Installing deepclaude ($Version) to $Dest ..."

# Download the PowerShell script
try {
  Invoke-WebRequest -UseBasicParsing "$Repo/deepclaude.ps1" -OutFile (Join-Path $Dest 'deepclaude.ps1')
} catch {
  Write-Host "ERROR: Download failed: $Repo/deepclaude.ps1" -ForegroundColor Red
  Write-Host "Check your internet connection or the VERSION env var." -ForegroundColor Red
  exit 1
}

# A .cmd shim so `deepclaude` works from cmd.exe and PowerShell alike.
$shim = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deepclaude.ps1" %*
'@
Set-Content -Path (Join-Path $Dest 'deepclaude.cmd') -Value $shim -Encoding ASCII

# Put the install dir on the user PATH if it isn't already.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if ($userPath -notlike "*$Dest*") {
  $newPath = if ($userPath) { "$userPath;$Dest" } else { $Dest }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$Dest"
  Write-Host "Added $Dest to your user PATH."
  Write-Host 'Open a NEW terminal for it to take effect.'
}

Write-Host 'Installed. Run: deepclaude'
Write-Host ''
Write-Host 'Checksum verification (optional):'
Write-Host "  Download: $Repo/checksums.txt"
Write-Host '  Verify:   Get-FileHash deepclaude.ps1 | Format-List'

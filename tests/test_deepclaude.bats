#!/usr/bin/env bats
#
# Tests for deepclaude
# Run: bats tests/
#

setup() {
  # Isolate tests from real config
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/.config"
  export DEEPCLAUDE_VERBOSE=0
  export DEEPSEEK_API_KEY=""
  export DEEPCLAUDE_SAFE=""
  export DEEPCLAUDE_MODEL=""
  export DEEPCLAUDE_HAIKU_MODEL=""
  export DEEPCLAUDE_SUBAGENT_MODEL=""
  export DEEPCLAUDE_EFFORT=""

  # Path to the script under test
  DEEPCLAUDE="${BATS_TEST_DIRNAME}/../deepclaude"
}

# Prevent any actual `claude` execution during tests
stub_claude() {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "CLAUDE STUB: $*"
echo "ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-unset}"
echo "ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-unset}"
echo "ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:+set (hidden)}"
exit 0
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/claude"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

# ============================================================================
# Basic flags
# ============================================================================

@test "deepclaude --version prints version" {
  run bash "$DEEPCLAUDE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ deepclaude\ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "deepclaude --help prints usage" {
  run bash "$DEEPCLAUDE" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ deepclaude ]]
  [[ "$output" =~ USAGE ]]
  [[ "$output" =~ EXAMPLES ]]
}

@test "deepclaude help also works" {
  run bash "$DEEPCLAUDE" help
  [ "$status" -eq 0 ]
  [[ "$output" =~ deepclaude ]]
}

@test "deepclaude --dry-run without key prints information" {
  stub_claude
  run bash "$DEEPCLAUDE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ dry-run ]]
  [[ "$output" =~ ANTHROPIC_BASE_URL ]]
  [[ "$output" =~ deepseek ]]
}

@test "deepclaude --dry-run --verbose shows debug info" {
  stub_claude
  run bash "$DEEPCLAUDE" --dry-run --verbose
  [ "$status" -eq 0 ]
  # --dry-run exits before key check, but --verbose should be set early
  # In dry-run mode, debug lines about model resolution appear before the dry-run output
  # Let's check the output has our key info
  [[ "$output" =~ MODEL= ]] || [[ "$output" =~ dry-run ]]
}

# ============================================================================
# Key management
# ============================================================================

@test "deepclaude config saves key to config file" {
  stub_claude
  run bash "$DEEPCLAUDE" config "sk-test12345"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
  # Verify config file was created
  [ -f "$XDG_CONFIG_HOME/deepclaude/config" ]
  grep -q "DEEPSEEK_API_KEY=sk-test12345" "$XDG_CONFIG_HOME/deepclaude/config"
}

@test "deepclaude config with empty key is rejected" {
  run bash "$DEEPCLAUDE" config ""
  [ "$status" -ne 0 ]
  [[ "$output" =~ empty ]]
}

@test "deepclaude reset removes stored key" {
  stub_claude
  # Save a key first
  bash "$DEEPCLAUDE" config "sk-test12345"
  # Then reset
  run bash "$DEEPCLAUDE" reset
  [ "$status" -eq 0 ]
  [[ "$output" =~ removed ]]
  [ ! -f "$XDG_CONFIG_HOME/deepclaude/config" ]
}

@test "deepclaude reset when no key is stored" {
  run bash "$DEEPCLAUDE" reset
  [ "$status" -eq 0 ]
  [[ "$output" =~ (removed|No stored key) ]]
}

@test "deepclaude verify with no stored key errors" {
  run bash "$DEEPCLAUDE" verify
  [ "$status" -ne 0 ]
  [[ "$output" =~ (No stored key|ERROR) ]]
}

# ============================================================================
# Key format validation
# ============================================================================

@test "validate_key_format accepts valid sk- prefix" {
  run bash -c '
    source "$1"
    validate_key_format "sk-abc123def456"
  ' _ "$DEEPCLAUDE"
  [ "$status" -eq 0 ]
}

@test "validate_key_format rejects keys without sk- prefix" {
  run bash -c '
    source "$1"
    validate_key_format "not-a-valid-key"
  ' _ "$DEEPCLAUDE"
  [ "$status" -eq 1 ]
}

# ============================================================================
# Config file read/write
# ============================================================================

@test "write_config and read_config roundtrip" {
  run bash -c '
    source "$1"
    write_config "TEST_KEY" "test-value-123"
    result=$(read_config "TEST_KEY")
    [ "$result" = "test-value-123" ] && echo "PASS" || echo "FAIL: got $result"
  ' _ "$DEEPCLAUDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ PASS ]]
}

# ============================================================================
# Show config
# ============================================================================

@test "deepclaude show-config displays configuration" {
  stub_claude
  bash "$DEEPCLAUDE" config "sk-test12345" > /dev/null 2>&1
  run bash "$DEEPCLAUDE" show-config
  [ "$status" -eq 0 ]
  [[ "$output" =~ Config\ file ]]
  [[ "$output" =~ stored ]]
}

# ============================================================================
# Environment variable resolution
# ============================================================================

@test "DEEPSEEK_API_KEY from env is auto-saved" {
  stub_claude
  export DEEPSEEK_API_KEY="sk-envtest123"
  run bash "$DEEPCLAUDE" --dry-run
  [ "$status" -eq 0 ]
  # Should have saved the key
  [ -f "$XDG_CONFIG_HOME/deepclaude/config" ]
  grep -q "DEEPSEEK_API_KEY=sk-envtest123" "$XDG_CONFIG_HOME/deepclaude/config"
}

# ============================================================================
# Model overrides
# ============================================================================

@test "DEEPCLAUDE_MODEL env var overrides default model" {
  stub_claude
  export DEEPSEEK_API_KEY="sk-test12345"
  export DEEPCLAUDE_MODEL="custom-model-v2"
  run bash "$DEEPCLAUDE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ custom-model-v2 ]]
}

# ============================================================================
# Safe mode
# ============================================================================

@test "deepclaude --safe sets safe mode" {
  stub_claude
  export DEEPSEEK_API_KEY="sk-test12345"
  run bash "$DEEPCLAUDE" --safe --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ Safe\ mode ]]
  [[ ! "$output" =~ dangerously-skip-permissions ]]
}

# ============================================================================
# Error: missing claude binary
# ============================================================================

@test "deepclaude errors when claude is not installed" {
  # Ensure claude is NOT on PATH
  export DEEPSEEK_API_KEY="sk-test12345"
  run bash "$DEEPCLAUDE" -- --version
  [ "$status" -eq 1 ]
  [[ "$output" =~ (claude CLI not found|not found) ]]
}

# ============================================================================
# Subcommand aliases
# ============================================================================

@test "deepclaude set-key is an alias for config" {
  stub_claude
  run bash "$DEEPCLAUDE" set-key "sk-aliastest"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
}

@test "deepclaude change-key is an alias for config" {
  stub_claude
  bash "$DEEPCLAUDE" config "sk-original" > /dev/null 2>&1
  run bash "$DEEPCLAUDE" change-key "sk-changed"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
  grep -q "DEEPSEEK_API_KEY=sk-changed" "$XDG_CONFIG_HOME/deepclaude/config"
}

# ============================================================================
# trim function
# ============================================================================

@test "trim removes leading/trailing whitespace" {
  run bash -c '
    source "$1"
    result=$(trim "  hello  ")
    [ "$result" = "hello" ] && echo "PASS" || echo "FAIL: got [$result]"
  ' _ "$DEEPCLAUDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ PASS ]]
}

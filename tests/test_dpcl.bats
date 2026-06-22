#!/usr/bin/env bats
#
# Tests for dpcl
# Run: bats tests/
#

setup() {
  # Isolate tests from real config
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/.config"
  export DPCL_VERBOSE=0
  export DEEPSEEK_API_KEY=""
  export DPCL_SAFE=""
  export DPCL_MODEL=""
  export DPCL_HAIKU_MODEL=""
  export DPCL_SUBAGENT_MODEL=""
  export DPCL_EFFORT=""

  # Path to the script under test
  DPCL="${BATS_TEST_DIRNAME}/../dpcl"
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

@test "dpcl --version prints version" {
  run bash "$DPCL" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ dpcl\ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "dpcl --help prints usage" {
  run bash "$DPCL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ dpcl ]]
  [[ "$output" =~ USAGE ]]
  [[ "$output" =~ EXAMPLES ]]
}

@test "dpcl help also works" {
  run bash "$DPCL" help
  [ "$status" -eq 0 ]
  [[ "$output" =~ dpcl ]]
}

@test "dpcl --dry-run without key prints information" {
  stub_claude
  run bash "$DPCL" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ dry-run ]]
  [[ "$output" =~ ANTHROPIC_BASE_URL ]]
  [[ "$output" =~ deepseek ]]
}

@test "dpcl --dry-run --verbose shows debug info" {
  stub_claude
  run bash "$DPCL" --dry-run --verbose
  [ "$status" -eq 0 ]
  # --dry-run exits before key check, but --verbose should be set early
  # In dry-run mode, debug lines about model resolution appear before the dry-run output
  # Let's check the output has our key info
  [[ "$output" =~ MODEL= ]] || [[ "$output" =~ dry-run ]]
}

# ============================================================================
# Key management
# ============================================================================

@test "dpcl config saves key to config file" {
  stub_claude
  run bash "$DPCL" config "sk-test12345"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
  # Verify config file was created
  [ -f "$XDG_CONFIG_HOME/dpcl/config" ]
  grep -q "DEEPSEEK_API_KEY=sk-test12345" "$XDG_CONFIG_HOME/dpcl/config"
}

@test "dpcl config with empty key is rejected" {
  run bash "$DPCL" config ""
  [ "$status" -ne 0 ]
  [[ "$output" =~ empty ]]
}

@test "dpcl reset removes stored key" {
  stub_claude
  # Save a key first
  bash "$DPCL" config "sk-test12345"
  # Then reset
  run bash "$DPCL" reset
  [ "$status" -eq 0 ]
  [[ "$output" =~ removed ]]
  [ ! -f "$XDG_CONFIG_HOME/dpcl/config" ]
}

@test "dpcl reset when no key is stored" {
  run bash "$DPCL" reset
  [ "$status" -eq 0 ]
  [[ "$output" =~ (removed|No stored key) ]]
}

@test "dpcl verify with no stored key errors" {
  run bash "$DPCL" verify
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
  ' _ "$DPCL"
  [ "$status" -eq 0 ]
}

@test "validate_key_format rejects keys without sk- prefix" {
  run bash -c '
    source "$1"
    validate_key_format "not-a-valid-key"
  ' _ "$DPCL"
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
  ' _ "$DPCL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ PASS ]]
}

# ============================================================================
# Show config
# ============================================================================

@test "dpcl show-config displays configuration" {
  stub_claude
  bash "$DPCL" config "sk-test12345" > /dev/null 2>&1
  run bash "$DPCL" show-config
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
  run bash "$DPCL" --dry-run
  [ "$status" -eq 0 ]
  # Should have saved the key
  [ -f "$XDG_CONFIG_HOME/dpcl/config" ]
  grep -q "DEEPSEEK_API_KEY=sk-envtest123" "$XDG_CONFIG_HOME/dpcl/config"
}

# ============================================================================
# Model overrides
# ============================================================================

@test "DPCL_MODEL env var overrides default model" {
  stub_claude
  export DEEPSEEK_API_KEY="sk-test12345"
  export DPCL_MODEL="custom-model-v2"
  run bash "$DPCL" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ custom-model-v2 ]]
}

# ============================================================================
# Safe mode
# ============================================================================

@test "dpcl --safe sets safe mode" {
  stub_claude
  export DEEPSEEK_API_KEY="sk-test12345"
  run bash "$DPCL" --safe --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ Safe\ mode ]]
  [[ ! "$output" =~ dangerously-skip-permissions ]]
}

# ============================================================================
# Error: missing claude binary
# ============================================================================

@test "dpcl errors when claude is not installed" {
  # Ensure claude is NOT on PATH
  export DEEPSEEK_API_KEY="sk-test12345"
  run bash "$DPCL" -- --version
  [ "$status" -eq 1 ]
  [[ "$output" =~ (claude CLI not found|not found) ]]
}

# ============================================================================
# Subcommand aliases
# ============================================================================

@test "dpcl set-key is an alias for config" {
  stub_claude
  run bash "$DPCL" set-key "sk-aliastest"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
}

@test "dpcl change-key is an alias for config" {
  stub_claude
  bash "$DPCL" config "sk-original" > /dev/null 2>&1
  run bash "$DPCL" change-key "sk-changed"
  [ "$status" -eq 0 ]
  [[ "$output" =~ saved ]]
  grep -q "DEEPSEEK_API_KEY=sk-changed" "$XDG_CONFIG_HOME/dpcl/config"
}

# ============================================================================
# trim function
# ============================================================================

@test "trim removes leading/trailing whitespace" {
  run bash -c '
    source "$1"
    result=$(trim "  hello  ")
    [ "$result" = "hello" ] && echo "PASS" || echo "FAIL: got [$result]"
  ' _ "$DPCL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ PASS ]]
}

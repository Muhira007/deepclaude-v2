#compdef dpcl
# Zsh completion for dpcl
# Source this file in your ~/.zshrc:
#   fpath=(/path/to/completions $fpath)
#   autoload -Uz compinit && compinit

_dpcl() {
  local -a subcommands flags

  subcommands=(
    'config:Set or change the stored DeepSeek API key'
    'set-key:Alias for config'
    'change-key:Alias for config'
    'change:Alias for config'
    'reset:Delete the stored API key'
    'update:Update dpcl to the latest version'
    'upgrade:Alias for update'
    'verify:Verify the stored API key against DeepSeek API'
    'show-config:Print current configuration'
    'show:Alias for show-config'
    'help:Show help message'
  )

  flags=(
    '--help[Show help message]'
    '--version[Show version number]'
    '--dry-run[Print what would be executed without running]'
    '--verbose[Print debug information]'
    '--safe[Run without --dangerously-skip-permissions]'
  )

  _arguments -s \
    $flags \
    '1: :{_describe "subcommand" subcommands}' \
    '*::args:'
}

_dpcl

# Bash completion for deepclaude
# Source this file in your ~/.bashrc:
#   source /path/to/completions/deepclaude.bash

_deepclaude() {
  local cur prev words cword
  _init_completion || return

  # Subcommands and flags
  local subcommands="config set-key change-key change reset update upgrade verify show-config show help"
  local flags="--help --version --dry-run --verbose --safe"

  case "$prev" in
    config|--config|set-key|--set-key|change|--change|change-key|--change-key)
      # After a key-setting subcommand, don't complete further
      COMPREPLY=()
      return
      ;;
    deepclaude)
      # First word: complete subcommands + flags
      COMPREPLY=($(compgen -W "$subcommands $flags" -- "$cur"))
      return
      ;;
  esac

  # Default: complete subcommands, flags, and files
  COMPREPLY=($(compgen -W "$subcommands $flags" -- "$cur"))
}

complete -F _deepclaude deepclaude

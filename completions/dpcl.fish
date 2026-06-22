# Fish completion for dpcl
# Place this file in ~/.config/fish/completions/dpcl.fish

# Subcommands
complete -c dpcl -n __fish_use_subcommand -a config -d 'Set or change the stored API key'
complete -c dpcl -n __fish_use_subcommand -a set-key -d 'Alias for config'
complete -c dpcl -n __fish_use_subcommand -a change-key -d 'Alias for config'
complete -c dpcl -n __fish_use_subcommand -a change -d 'Alias for config'
complete -c dpcl -n __fish_use_subcommand -a reset -d 'Delete the stored API key'
complete -c dpcl -n __fish_use_subcommand -a update -d 'Update to the latest version'
complete -c dpcl -n __fish_use_subcommand -a upgrade -d 'Alias for update'
complete -c dpcl -n __fish_use_subcommand -a verify -d 'Verify the stored API key'
complete -c dpcl -n __fish_use_subcommand -a show-config -d 'Print current configuration'
complete -c dpcl -n __fish_use_subcommand -a show -d 'Alias for show-config'
complete -c dpcl -n __fish_use_subcommand -a help -d 'Show help message'

# Flags
complete -c dpcl -l help -d 'Show help message'
complete -c dpcl -l version -d 'Show version number'
complete -c dpcl -l dry-run -d 'Print what would be executed without running'
complete -c dpcl -l verbose -d 'Print debug information'
complete -c dpcl -l safe -d 'Run without --dangerously-skip-permissions'

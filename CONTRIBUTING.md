# Contributing to DeepClaude

Thanks for your interest in improving DeepClaude!

## Development setup

```bash
git clone https://github.com/RafiulM/deepclaude.git
cd deepclaude
```

No build step — the scripts are interpreted directly.

## Running tests

```bash
# Install dependencies
# macOS:       brew install bats-core shellcheck
# Ubuntu:      sudo apt-get install bats shellcheck
# Arch Linux:  sudo pacman -S bats shellcheck

# Run linting
make lint          # or: shellcheck deepclaude install.sh

# Run tests
make test          # or: bats tests/

# Run both
make check
```

## Project structure

```
deepclaude/
├── deepclaude          # Main Bash script (Linux/macOS)
├── deepclaude.ps1      # PowerShell script (Windows)
├── install.sh          # Bash installer
├── install.ps1         # PowerShell installer
├── completions/        # Shell completions (bash/zsh/fish)
├── tests/              # BATS test suite
├── .github/workflows/  # CI pipeline
├── Makefile            # Dev commands
└── README.md           # User-facing docs
```

## Code conventions

### Bash (`deepclaude`, `install.sh`)

- Use `set -euo pipefail`
- Functions are `snake_case`
- Global variables are `UPPER_CASE`
- Use `printf` instead of `echo`
- Keep line length under ~100 chars
- Run `shellcheck` before committing

### PowerShell (`deepclaude.ps1`, `install.ps1`)

- Use `Verb-Noun` function naming
- `$Script:` scope for module-level variables
- Keep line length under ~100 chars
- Run `Invoke-ScriptAnalyzer` before committing

## Adding a feature

1. Fork the repo and create a feature branch
2. Implement in **both** `deepclaude` (Bash) and `deepclaude.ps1` (PowerShell)
3. Add tests in `tests/test_deepclaude.bats`
4. Update `README.md` if the feature changes user-facing behavior
5. Run `make check` to ensure all checks pass
6. Open a PR against `main`

## Versioning

We follow [SemVer](https://semver.org/). To bump the version:

```bash
make bump
```

This updates `VERSION` in both `deepclaude` and `deepclaude.ps1`.

## Release checklist

1. [ ] `make check` passes
2. [ ] Version bumped in both scripts
3. [ ] CHANGELOG entry added
4. [ ] Git tag created: `git tag -a v1.x.x -m "Release v1.x.x"`
5. [ ] Push tag: `git push origin v1.x.x`
6. [ ] GitHub Release created with release notes

## Getting help

Open an issue on GitHub: https://github.com/RafiulM/deepclaude/issues

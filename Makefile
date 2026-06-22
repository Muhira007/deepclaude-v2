.PHONY: lint test check clean install

# --- Linting -----------------------------------------------------------------
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null)

lint:
ifndef SHELLCHECK
	$(error "shellcheck not found. Install: https://github.com/koalaman/shellcheck")
endif
	$(SHELLCHECK) deepclaude install.sh

# --- Tests -------------------------------------------------------------------
BATS := $(shell command -v bats 2>/dev/null)

test:
ifndef BATS
	$(error "bats not found. Install: https://github.com/bats-core/bats-core")
endif
	$(BATS) tests/

# --- Combined check ----------------------------------------------------------
check: lint test
	@echo "All checks passed."

# --- Clean -------------------------------------------------------------------
clean:
	rm -f tests/*.log

# --- Install (local dev) -----------------------------------------------------
install:
	cp deepclaude ~/.local/bin/deepclaude
	chmod +x ~/.local/bin/deepclaude
	@echo "Installed to ~/.local/bin/deepclaude"

# --- Shell completions (local dev) -------------------------------------------
completions: completions/deepclaude.bash completions/deepclaude.zsh completions/deepclaude.fish
	@echo "Completions generated."

# --- Version bump ------------------------------------------------------------
bump:
	@read -p "New version (e.g. 1.1.0): " v; \
	sed -i "s/^VERSION=.*/VERSION=\"$$v\"/" deepclaude; \
	sed -i "s/Version\s*=\s*'.*'/Version      = '$$v'/" deepclaude.ps1; \
	echo "Version bumped to $$v"

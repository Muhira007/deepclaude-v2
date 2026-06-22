.PHONY: lint test check clean install

# --- Linting -----------------------------------------------------------------
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null)

lint:
ifndef SHELLCHECK
	$(error "shellcheck not found. Install: https://github.com/koalaman/shellcheck")
endif
	$(SHELLCHECK) dpcl install.sh

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
	cp dpcl ~/.local/bin/dpcl
	chmod +x ~/.local/bin/dpcl
	@echo "Installed to ~/.local/bin/dpcl"

# --- Shell completions (local dev) -------------------------------------------
completions: completions/dpcl.bash completions/dpcl.zsh completions/dpcl.fish
	@echo "Completions generated."

# --- Version bump ------------------------------------------------------------
bump:
	@read -p "New version (e.g. 1.1.0): " v; \
	sed -i "s/^VERSION=.*/VERSION=\"$$v\"/" dpcl; \
	sed -i "s/Version\s*=\s*'.*'/Version      = '$$v'/" dpcl.ps1; \
	echo "Version bumped to $$v"

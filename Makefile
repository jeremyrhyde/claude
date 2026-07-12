# codesync — installation
#
#   make setup             install required system packages (jq, curl, git)
#   make install           Syncthing (if missing) + the `codesync` command
#   make install-globally  runs 'install' first, then registers + installs the plugin (user scope)
#   make all               setup + install + install-globally
#
# Focused on codesync for now; other subsystems can add targets later.

REPO_ROOT := $(CURDIR)
CODESYNC  := $(REPO_ROOT)/codesync

.PHONY: help setup install install-codesync install-globally all

help:
	@echo "codesync install targets:"
	@echo "  make setup             install required packages (jq, curl, git)"
	@echo "  make install           Syncthing (if missing) + the 'codesync' command"
	@echo "  make install-globally  install (above) + register/install the codesync plugin (user scope)"
	@echo "  make all               setup + install + install-globally"

setup:
	@echo "==> Installing required packages (jq, curl, git)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		command -v brew >/dev/null 2>&1 || { echo "Homebrew is required on macOS: https://brew.sh"; exit 1; }; \
		brew install jq curl git; \
	elif command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y jq curl git; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y jq curl git; \
	else \
		echo "No supported package manager found — install jq, curl, git manually."; exit 1; \
	fi

install: install-codesync

install-codesync:
	@if command -v syncthing >/dev/null 2>&1; then \
		echo "==> Syncthing present: $$(syncthing --version 2>/dev/null | awk '{print $$2}')"; \
	else \
		echo "==> Syncthing not found — installing via install-syncthing.sh"; \
		bash "$(CODESYNC)/install-syncthing.sh"; \
	fi
	@echo "==> Installing the codesync command"
	@bash "$(CODESYNC)/install.sh"

install-globally: install
	@command -v claude >/dev/null 2>&1 || { echo "The 'claude' CLI is required — install Claude Code first."; exit 1; }
	@echo "==> Registering marketplace + installing the codesync plugin (user scope)"
	@claude plugin marketplace add "$(REPO_ROOT)" 2>/dev/null || echo "   (marketplace already registered)"
	@claude plugin install codesync@jrhyde-tools --scope user 2>/dev/null \
		|| claude plugin update codesync@jrhyde-tools 2>/dev/null \
		|| echo "   (plugin already installed)"
	@echo "==> Done. Run /reload-plugins (or restart claude) to see /codesync:*"

all: setup install install-globally

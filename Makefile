# jrhyde-tools — installation
#
#   make setup             install required system packages (jq, curl, git)
#   make install           Syncthing (if missing) + the `codesync` command
#   make install-globally  'install' + codesync plugin + skills (user scope)
#   make install-skills    link this repo's skills into ~/.claude/skills (all projects)
#   make uninstall-skills  remove those skill links
#   make all               setup + install + install-globally
#
# This repo is the central source of truth for custom Claude skills: every
# skill under .claude/skills/ is symlinked into ~/.claude/skills/ so it is
# available in every project on the machine. New machine: clone this repo,
# then `make install-skills` (a `git pull` here updates them everywhere).

REPO_ROOT   := $(CURDIR)
CODESYNC    := $(REPO_ROOT)/codesync
SKILLS_SRC  := $(REPO_ROOT)/.claude/skills
SKILLS_DEST := $(HOME)/.claude/skills

.PHONY: help setup install install-codesync install-globally install-skills uninstall-skills all

help:
	@echo "jrhyde-tools install targets:"
	@echo "  make setup             install required packages (jq, curl, git)"
	@echo "  make install           Syncthing (if missing) + the 'codesync' command"
	@echo "  make install-globally  install (above) + codesync plugin + skills (user scope)"
	@echo "  make install-skills    link .claude/skills/* into ~/.claude/skills (all projects)"
	@echo "  make uninstall-skills  remove the skill links this repo created"
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

install-globally: install install-skills
	@command -v claude >/dev/null 2>&1 || { echo "The 'claude' CLI is required — install Claude Code first."; exit 1; }
	@echo "==> Registering marketplace + installing the codesync plugin (user scope)"
	@claude plugin marketplace add "$(REPO_ROOT)" 2>/dev/null || echo "   (marketplace already registered)"
	@claude plugin install codesync@jrhyde-tools --scope user 2>/dev/null \
		|| claude plugin update codesync@jrhyde-tools 2>/dev/null \
		|| echo "   (plugin already installed)"
	@echo "==> Done. Run /reload-plugins (or restart claude) to see /codesync:*"

# Symlink every skill under .claude/skills/ into ~/.claude/skills/ so it is
# discoverable in every project. Symlinks (not copies) mean a `git pull` here
# updates the skills everywhere at once. Idempotent; re-run any time. A real
# directory already at a target (e.g. a non-link skill) is left untouched.
install-skills:
	@echo "==> Linking skills: $(SKILLS_SRC) -> $(SKILLS_DEST)"
	@mkdir -p "$(SKILLS_DEST)"
	@n=0; for d in "$(SKILLS_SRC)"/*/; do \
		[ -d "$$d" ] || continue; \
		d="$${d%/}"; name=$$(basename "$$d"); target="$(SKILLS_DEST)/$$name"; \
		if [ -e "$$target" ] && [ ! -L "$$target" ]; then \
			echo "   SKIP $$name — a real directory exists at $$target (remove it to replace)"; \
		elif ln -sfn "$$d" "$$target" 2>/dev/null; then \
			echo "   linked $$name"; n=$$((n+1)); \
		else \
			echo "   symlinks unsupported — copying $$name"; rm -rf "$$target"; cp -r "$$d" "$$target"; n=$$((n+1)); \
		fi; \
	done; \
	echo "==> $$n skill(s) available globally. Restart claude (or /reload) to pick up new ones."

# Remove only the links that point back into this repo; leaves other skills
# (e.g. claude.ai-synced built-ins under synced/) alone.
uninstall-skills:
	@for d in "$(SKILLS_SRC)"/*/; do \
		[ -d "$$d" ] || continue; \
		name=$$(basename "$${d%/}"); target="$(SKILLS_DEST)/$$name"; \
		if [ -L "$$target" ] && [ "$$(readlink "$$target")" = "$${d%/}" ]; then \
			rm -f "$$target" && echo "   unlinked $$name"; \
		fi; \
	done

all: setup install install-globally

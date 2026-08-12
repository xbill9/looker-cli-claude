# Makefile for the Looker CLI + MCP setup project.
#
# Everything here installs tooling into the project root. Downloaded binaries
# are gitignored — never commit them, and never bake credentials into a target.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Looker CLI — https://github.com/looker-open-source/looker-cli
# Release binaries are published as GitHub release assets, laid out as:
#   looker-cli_<version-without-v>_<os>_<arch>.tar.gz  (.zip on windows)
# Leave LOOKER_CLI_VERSION empty to track the latest release, or pin it:
#   make cli LOOKER_CLI_VERSION=v0.4.8
LOOKER_CLI_REPO     := looker-open-source/looker-cli
LOOKER_CLI_VERSION  ?=
LOOKER_CLI_FALLBACK := v0.4.8
LOOKER_CLI_BIN      := $(ROOT_DIR)/looker-cli

# Article source for `make medium`. Override to convert a different one:
#   make medium ARTICLE=docs/other-article.md
ARTICLE ?= docs/looker-native-mcp-with-claude-code.md

.DEFAULT_GOAL := help
.PHONY: help cli login logout check medium

help:
	@echo "Targets:"
	@echo "  cli     Download the Looker CLI into $(LOOKER_CLI_BIN)"
	@echo "          Pin a release with: make cli LOOKER_CLI_VERSION=v0.4.8"
	@echo "  login   Get a fresh Looker session token (./lk login)"
	@echo "  logout  Invalidate the stored session token (./lk logout)"
	@echo "  check   Smoke-test the connection (./lk user me)"
	@echo "  medium  Derive the Medium variant of an article (.md + .html)"
	@echo "          Defaults to $(ARTICLE); override with ARTICLE=..."
	@echo
	@echo "Credentials come from 'source set_env.sh'. The MCP server is hosted by"
	@echo "the Looker instance itself - there is no local server binary."
	@echo "Run CLI commands through the wrapper: ./lk <command> — see README.md."

# Convenience wrappers around ./lk. Credentials come from .env; nothing here
# ever takes a secret as a make variable.
login:
	@$(ROOT_DIR)/lk login

logout:
	@$(ROOT_DIR)/lk logout

check:
	@$(ROOT_DIR)/lk user me

# Strip dev.to frontmatter, rewrite tables as lists (Medium renders neither),
# and render the HTML that Medium's importer consumes. Requires pandoc.
medium:
	@python3 $(ROOT_DIR)/scripts/medium.py "$(ARTICLE)"

# Download (or re-download) the Looker CLI for this host's OS/arch, verifying
# the published SHA-256 checksum before installing.
cli:
	@os=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	arch=$$(uname -m); \
	case "$$arch" in \
	  x86_64|amd64) arch=amd64 ;; \
	  aarch64|arm64) arch=arm64 ;; \
	  *) echo "Error: unsupported architecture '$$arch'." >&2; exit 1 ;; \
	esac; \
	case "$$os" in mingw*|cygwin*|msys*) os=windows ;; esac; \
	case "$$os" in \
	  linux|darwin) ext=tar.gz; binary=looker-cli ;; \
	  windows) ext=zip; binary=looker-cli.exe ;; \
	  *) echo "Error: unsupported OS '$$os'." >&2; exit 1 ;; \
	esac; \
	version="$(LOOKER_CLI_VERSION)"; \
	if [ -z "$$version" ]; then \
	  version=$$(curl -sL "https://api.github.com/repos/$(LOOKER_CLI_REPO)/releases/latest" \
	    | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/') || true; \
	fi; \
	if [ -z "$$version" ]; then \
	  version="$(LOOKER_CLI_FALLBACK)"; \
	  echo "Warning: could not resolve the latest looker-cli release; falling back to $$version." >&2; \
	fi; \
	bare=$${version#v}; \
	asset="looker-cli_$${bare}_$${os}_$${arch}.$${ext}"; \
	base="https://github.com/$(LOOKER_CLI_REPO)/releases/download/$${version}"; \
	tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	echo "Downloading $$base/$$asset..."; \
	curl -sSL -f -o "$$tmp/$$asset" "$$base/$$asset"; \
	if curl -sL -f -o "$$tmp/checksums.txt" "$$base/looker-cli_$${bare}_checksums.txt"; then \
	  if command -v sha256sum >/dev/null 2>&1; then check="sha256sum -c -"; \
	  elif command -v shasum >/dev/null 2>&1; then check="shasum -a 256 -c -"; \
	  else check=""; echo "Warning: no sha256 tool found; skipping checksum verification." >&2; fi; \
	  if [ -n "$$check" ]; then \
	    ( cd "$$tmp" && grep " $$asset$$" checksums.txt | $$check ) \
	      || { echo "Error: checksum verification failed for $$asset." >&2; exit 1; }; \
	  fi; \
	else \
	  echo "Warning: checksums file unavailable; skipping verification." >&2; \
	fi; \
	if [ "$$ext" = "zip" ]; then \
	  command -v unzip >/dev/null 2>&1 || { echo "Error: 'unzip' is required to install on windows." >&2; exit 1; }; \
	  unzip -q -o "$$tmp/$$asset" "$$binary" -d "$$tmp"; \
	else \
	  tar -xzf "$$tmp/$$asset" -C "$$tmp" "$$binary"; \
	fi; \
	mv "$$tmp/$$binary" "$(LOOKER_CLI_BIN)"; \
	chmod +x "$(LOOKER_CLI_BIN)"; \
	echo "Installed looker-cli $$version to $(LOOKER_CLI_BIN)"; \
	"$(LOOKER_CLI_BIN)" version || true

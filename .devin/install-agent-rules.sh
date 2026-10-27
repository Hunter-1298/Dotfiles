#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RULES_FILE="$DOTFILES_DIR/.devin/AGENTS.md"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR=""

if [ ! -f "$RULES_FILE" ]; then
	printf 'Missing shared rules: %s\n' "$RULES_FILE" >&2
	exit 1
fi

link_rules() {
	local name=$1 dst=$2

	if [ -L "$dst" ] && [ "$dst" -ef "$RULES_FILE" ]; then
		return 0
	fi
	if [ -d "$dst" ]; then
		printf 'Refusing to replace a directory: %s\n' "$dst" >&2
		return 1
	fi

	mkdir -p "$(dirname "$dst")"
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		if [ -z "$BACKUP_DIR" ]; then
			mkdir -p "$CONFIG_HOME/devin/backups"
			BACKUP_DIR="$(mktemp -d "$CONFIG_HOME/devin/backups/agent-rules.XXXXXXXX")"
		fi
		if [ -L "$dst" ] && [ -f "$dst" ]; then
			cp -pL "$dst" "$BACKUP_DIR/$name.contents"
		fi
		mv "$dst" "$BACKUP_DIR/$name"
	fi
	ln -s "$RULES_FILE" "$dst"
	printf 'Linked %s\n' "$dst"
}

link_rules devin-AGENTS.md "$CONFIG_HOME/devin/AGENTS.md"
link_rules claude-CLAUDE.md "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
link_rules codex-AGENTS.md "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
link_rules gemini-GEMINI.md "$HOME/.gemini/GEMINI.md"
link_rules pi-AGENTS.md "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/AGENTS.md"

printf 'Shared agent rules: %s\n' "$RULES_FILE"
if [ -n "$BACKUP_DIR" ]; then
	printf 'Previous instructions backed up in %s\n' "$BACKUP_DIR"
fi

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

link_path() {
	local name=$1 src=$2 dst=$3

	if [ -L "$dst" ] && [ "$dst" -ef "$src" ]; then
		return 0
	fi
	if [ -d "$dst" ] && [ ! -L "$dst" ]; then
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
	ln -s "$src" "$dst"
	printf 'Linked %s\n' "$dst"
}

link_rules() {
	link_path "$1" "$RULES_FILE" "$2"
}

link_rules devin-AGENTS.md "$CONFIG_HOME/devin/AGENTS.md"
link_rules claude-CLAUDE.md "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
link_rules codex-AGENTS.md "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
link_rules gemini-GEMINI.md "$HOME/.gemini/GEMINI.md"
link_rules pi-AGENTS.md "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/AGENTS.md"
link_rules opencode-AGENTS.md "$CONFIG_HOME/opencode/AGENTS.md"

for skill in "$DOTFILES_DIR"/.devin/skills/*/; do
	skill=${skill%/}
	[ -f "$skill/SKILL.md" ] || continue
	name=$(basename "$skill")
	link_path "agents-skills-$name" "$skill" "$HOME/.agents/skills/$name" || :
	link_path "claude-skills-$name" "$skill" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/$name" || :
done

printf 'Shared agent rules: %s\n' "$RULES_FILE"
printf 'Shared skills: %s\n' "$DOTFILES_DIR/.devin/skills"
if [ -n "$BACKUP_DIR" ]; then
	printf 'Previous instructions backed up in %s\n' "$BACKUP_DIR"
fi

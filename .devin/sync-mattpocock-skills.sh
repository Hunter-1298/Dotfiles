#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SKILLS_DIR="$DOTFILES_DIR/.devin/skills"
MANIFEST="$SKILLS_DIR/.mattpocock-skills"
CLONE="${TMPDIR:-/tmp}/mattpocock-skills"

rm -rf "$CLONE"
trap 'rm -rf "$CLONE"' EXIT
git clone --depth 1 --quiet https://github.com/mattpocock/skills.git "$CLONE"

managed() { [ -f "$MANIFEST" ] && grep -qxF "$1" "$MANIFEST"; }

if [ -f "$MANIFEST" ]; then
	while read -r name; do
		case $name in '#'* | '') continue ;; esac
		[ -d "$CLONE/skills/engineering/$name" ] || [ -d "$CLONE/skills/productivity/$name" ] && continue
		rm -rf "${SKILLS_DIR:?}/$name"
		printf 'Removed %s (no longer promoted upstream)\n' "$name"
	done <"$MANIFEST"
fi

synced=()
for src in "$CLONE"/skills/engineering/*/ "$CLONE"/skills/productivity/*/; do
	src=${src%/}
	name=$(basename "$src")
	[ -f "$src/SKILL.md" ] || continue
	if [ -e "$SKILLS_DIR/$name" ] && ! managed "$name"; then
		printf 'Skipped %s: a skill you own already uses that name\n' "$name" >&2
		continue
	fi
	rm -rf "${SKILLS_DIR:?}/$name"
	cp -R "$src" "$SKILLS_DIR/$name"
	cp "$CLONE/LICENSE" "$SKILLS_DIR/$name/LICENSE"
	synced+=("$name")
done

{
	printf '# Managed by sync-mattpocock-skills.sh from mattpocock/skills@%s\n' "$(git -C "$CLONE" rev-parse --short HEAD)"
	printf '%s\n' ${synced[@]+"${synced[@]}"}
} >"$MANIFEST"

printf 'Synced %d skills from mattpocock/skills. Changes to review before committing:\n' "${#synced[@]}"
git -C "$DOTFILES_DIR" status --short -- .devin/skills
printf 'Run .devin/install-agent-rules.sh to link any new skills.\n'

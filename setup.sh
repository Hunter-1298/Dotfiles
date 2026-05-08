#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup.sh — bootstrap a new Linux or macOS laptop with hshayde's dotfiles.
#
# Idempotent: safe to re-run. Each step checks state before acting.
#
# Skip individual sections via env flags:
#   SKIP_INSTALLS=1     skip core CLI installs (configs only)
#   SKIP_NODE=1         skip nvm + node install
#   SKIP_PI=1           skip pi + pi package install
#   SKIP_PI_MONITOR=1   skip cloning pi-monitor companion repo
#
# Things this script intentionally does NOT install (per your preference):
#   - oh-my-zsh, powerlevel10k        (your zshrc references them; install yourself)
#   - tmux TPM plugins                 (open tmux, prefix + I)
#   - nvim plugin manager bootstrap    (open nvim; lazy.nvim/etc. self-installs)
#   - GUI apps: Ghostty, Zed           (configs are symlinked but apps not installed)
# -----------------------------------------------------------------------------

set -euo pipefail

DOTFILES_DIR="$HOME/.config/Dotfiles"
PI_MONITOR_REPO="https://github.com/hshayde/pi-monitor.git"
PI_MONITOR_DIR="$HOME/Projects/pi-monitor"

BLUE=$'\033[1;34m'; YELLOW=$'\033[1;33m'; GREEN=$'\033[1;32m'; RESET=$'\033[0m'
log()  { printf "%s==>%s %s\n" "$BLUE" "$RESET" "$*"; }
warn() { printf "%s!!  %s%s\n" "$YELLOW" "$*" "$RESET" >&2; }
ok()   { printf "%s ✓ %s%s\n" "$GREEN" "$*" "$RESET"; }

case "$(uname -s)" in
	Linux*)  OS=linux ;;
	Darwin*) OS=macos ;;
	*) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
log "Bootstrapping dotfiles on $OS"

# -----------------------------------------------------------------------------
# Tool installs
# -----------------------------------------------------------------------------

apt_updated=0
apt_update_once() {
	if [ "$OS" = linux ] && [ "$apt_updated" -eq 0 ]; then
		log "apt-get update"
		sudo apt-get update -qq
		apt_updated=1
	fi
}

ensure_brew() {
	if ! command -v brew >/dev/null 2>&1; then
		log "Installing Homebrew"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
}

# install_tool <command-to-check> <apt-package> <brew-package>
# Skips if the command already resolves on PATH.
install_tool() {
	local cmd=$1 apt_pkg=$2 brew_pkg=$3
	if command -v "$cmd" >/dev/null 2>&1; then return 0; fi
	case "$OS" in
		linux)
			apt_update_once
			log "apt install $apt_pkg"
			sudo apt-get install -y -qq "$apt_pkg" || warn "apt failed for $apt_pkg — install manually"
			;;
		macos)
			log "brew install $brew_pkg"
			brew install "$brew_pkg" || warn "brew failed for $brew_pkg — install manually"
			;;
	esac
}

install_eza_linux() {
	# eza is in default Ubuntu repos starting from 24.04; older distros need a
	# tarball drop-in. Try apt first, fall back to a static binary in ~/.local/bin.
	if command -v eza >/dev/null 2>&1; then return 0; fi
	apt_update_once
	if sudo apt-get install -y -qq eza 2>/dev/null; then return 0; fi
	warn "apt repo lacks eza; downloading static binary to ~/.local/bin"
	mkdir -p "$HOME/.local/bin"
	local tmp; tmp=$(mktemp -d)
	if curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
			| tar xz -C "$tmp"; then
		mv "$tmp/eza" "$HOME/.local/bin/eza"
		chmod +x "$HOME/.local/bin/eza"
		ok "installed eza to ~/.local/bin/eza"
	else
		warn "eza download failed — install manually"
	fi
	rm -rf "$tmp"
}

if [ "${SKIP_INSTALLS:-0}" != "1" ]; then
	if [ "$OS" = macos ]; then ensure_brew; fi

	# (cmd, apt-name, brew-name)
	install_tool curl     curl     curl
	install_tool git      git      git
	install_tool zsh      zsh      zsh
	install_tool tmux     tmux     tmux
	install_tool nvim     neovim   neovim
	install_tool rg       ripgrep  ripgrep
	install_tool fzf      fzf      fzf
	install_tool jq       jq       jq
	install_tool gh       gh       gh

	if [ "$OS" = linux ]; then install_eza_linux
	else install_tool eza eza eza
	fi
else
	log "SKIP_INSTALLS=1 — skipping CLI installs"
fi

# -----------------------------------------------------------------------------
# Node via nvm (so pi has a node to install into)
# -----------------------------------------------------------------------------

install_nvm_node() {
	if [ "${SKIP_NODE:-0}" = "1" ]; then
		log "SKIP_NODE=1 — skipping nvm/node"
		return 0
	fi

	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		log "Installing nvm"
		PROFILE=/dev/null bash -c \
			"curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
	fi
	# shellcheck disable=SC1091
	. "$NVM_DIR/nvm.sh"

	if ! command -v node >/dev/null 2>&1; then
		log "nvm install --lts"
		nvm install --lts
		nvm alias default 'lts/*'
	fi
}

install_nvm_node

# -----------------------------------------------------------------------------
# pi-monitor companion repo
# -----------------------------------------------------------------------------

if [ "${SKIP_PI_MONITOR:-0}" != "1" ]; then
	if [ ! -d "$PI_MONITOR_DIR/.git" ]; then
		log "Cloning pi-monitor → $PI_MONITOR_DIR"
		mkdir -p "$(dirname "$PI_MONITOR_DIR")"
		git clone "$PI_MONITOR_REPO" "$PI_MONITOR_DIR" || \
			warn "pi-monitor clone failed — pi-monitor-heartbeat extension symlink will dangle"
	else
		ok "pi-monitor already cloned"
	fi
else
	log "SKIP_PI_MONITOR=1 — skipping pi-monitor clone"
fi

# -----------------------------------------------------------------------------
# Symlink helper: idempotent, backs up real files/dirs before linking
# -----------------------------------------------------------------------------

backup_and_link() {
	local src=$1 dst=$2

	if [ ! -e "$src" ] && [ ! -L "$src" ]; then
		warn "missing source: $src — skipping"
		return 0
	fi

	if [ -L "$dst" ]; then
		local current; current=$(readlink "$dst")
		if [ "$current" = "$src" ]; then return 0; fi
		rm "$dst"
	elif [ -e "$dst" ]; then
		local backup="${dst}.bak.$(date +%s)"
		warn "backing up existing $dst → $backup"
		mv "$dst" "$backup"
	fi

	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	ok "linked $dst → $src"
}

# -----------------------------------------------------------------------------
# Shell rcs and friends
# -----------------------------------------------------------------------------

backup_and_link "$DOTFILES_DIR/zsh/zshrc"        "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/bash/.bashrc"     "$HOME/.bashrc"
backup_and_link "$DOTFILES_DIR/bash/.bash_profile" "$HOME/.bash_profile"
backup_and_link "$DOTFILES_DIR/git/.gitconfig"   "$HOME/.gitconfig"
backup_and_link "$DOTFILES_DIR/tmux/tmux.conf"   "$HOME/.tmux.conf"

# -----------------------------------------------------------------------------
# XDG config dirs
# -----------------------------------------------------------------------------

# Linux + macOS both honor ~/.config/ for these tools.
backup_and_link "$DOTFILES_DIR/nvim"    "$HOME/.config/nvim"
backup_and_link "$DOTFILES_DIR/helix"   "$HOME/.config/helix"
backup_and_link "$DOTFILES_DIR/ghostty" "$HOME/.config/ghostty"
backup_and_link "$DOTFILES_DIR/zellij"  "$HOME/.config/zellij"
backup_and_link "$DOTFILES_DIR/wandb"   "$HOME/.config/wandb"

# Zed: ~/.config/zed on Linux, ~/Library/Application Support/Zed on macOS.
if [ "$OS" = macos ]; then
	backup_and_link "$DOTFILES_DIR/zed" "$HOME/Library/Application Support/Zed"
else
	backup_and_link "$DOTFILES_DIR/zed" "$HOME/.config/zed"
fi

# -----------------------------------------------------------------------------
# pi coding agent: link tracked config + install packages
# -----------------------------------------------------------------------------

# ~/.pi → ~/.config/pi (pi's discovery root)
mkdir -p "$HOME/.config/pi"
ln -sfn "$HOME/.config/pi" "$HOME/.pi"

# Symlink each tracked top-level item from Dotfiles into the live agent dir.
# Runtime/local items (sessions/, run-history.jsonl, auth.json, .heartbeats/,
# node_modules/, caches, bin/fd) stay outside the dotfiles repo — see
# pi/agent/.gitignore. Discovered dynamically from git so new tracked dirs
# (e.g. `types/`, future additions) are picked up without editing this script.
mkdir -p "$HOME/.config/pi/agent"
mapfile -t PI_TRACKED < <(
	cd "$DOTFILES_DIR" && \
		git ls-tree --name-only HEAD pi/agent/ \
			| sed 's|^pi/agent/||' \
			| grep -v '^\.gitignore$'
)
for item in "${PI_TRACKED[@]}"; do
	src="$DOTFILES_DIR/pi/agent/$item"
	dst="$HOME/.config/pi/agent/$item"
	if [ -e "$src" ]; then
		ln -sfn "$src" "$dst"
	fi
done

# Install pi itself, then every npm:* package listed in settings.json.
if [ "${SKIP_PI:-0}" = "1" ]; then
	log "SKIP_PI=1 — skipping pi install"
elif ! command -v npm >/dev/null 2>&1; then
	warn "npm not found — install Node.js, then re-run to install pi packages"
else
	if ! command -v pi >/dev/null 2>&1; then
		log "npm i -g @mariozechner/pi-coding-agent"
		npm i -g @mariozechner/pi-coding-agent
	fi
	if command -v jq >/dev/null 2>&1; then
		settings="$DOTFILES_DIR/pi/agent/settings.json"
		mapfile -t pi_pkgs < <(jq -r '.packages[]? | select(startswith("npm:")) | sub("^npm:"; "")' "$settings")
		if [ "${#pi_pkgs[@]}" -gt 0 ]; then
			log "Installing ${#pi_pkgs[@]} pi packages from settings.json"
			npm i -g "${pi_pkgs[@]}"
		fi
	else
		warn "jq not found — skipping pi package install. Install jq and re-run."
	fi
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

cat <<EOF

${GREEN}Dotfiles installed.${RESET}

Manual follow-ups (intentionally not automated):
  • oh-my-zsh:    sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  • powerlevel10k: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \\
                     \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  • tmux TPM:     git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
                  then in tmux: prefix + I to install plugins
  • nvim plugins: open nvim once; the plugin manager in init.lua self-installs
  • set zsh as login shell: chsh -s "\$(command -v zsh)"

Per-laptop env (not in dotfiles): pi 'auth.json' must be re-created (pi will
prompt on first run), and any private API keys in your shell rc.
EOF

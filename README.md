# Dotfiles

Living document of the configs I run for my workflow.

## Layout

| Path           | What it is                                                           |
| -------------- | -------------------------------------------------------------------- |
| `bash/`        | `.bashrc`                                                            |
| `zsh/zshrc`    | Zsh + oh-my-zsh + Powerlevel10k                                      |
| `git/`         | `.gitconfig`                                                         |
| `tmux/`        | tmux config                                                          |
| `nvim/`        | Neovim config                                                        |
| `helix/`       | Helix config                                                         |
| `ghostty/`     | Ghostty terminal config                                              |
| `zellij/`      | Zellij multiplexer + layouts                                         |
| `zed/`         | Zed editor settings                                                  |
| `wandb/`       | Weights & Biases                                                     |
| `configstore/` | npm/configstore data                                                 |
| `nvm/`         | Node version manager                                                 |
| `pi/agent/`    | [pi](https://github.com/mariozechner/pi) coding-agent configs (see below) |

## Install

```bash
./setup.sh
```

This symlinks `~/.zshrc`, `~/.bashrc`, and `~/.gitconfig` to their dotfiles equivalents.

For the pi agent configs, symlink the directory or copy what you need:

```bash
mkdir -p ~/.pi
ln -sfn ~/.config/Dotfiles/pi/agent ~/.pi/agent
```

## Related repos

These are kept as separate repos but used together with this dotfiles setup.

- **[pi-monitor](https://github.com/hshayde/pi-monitor)** — observability/monitoring for `pi` coding-agent sessions. Provides the `pi-monitor-heartbeat` extension that `pi/agent/extensions/` symlinks into. Clone alongside this repo:
  ```bash
  git clone https://github.com/hshayde/pi-monitor.git ~/Projects/pi-monitor
  ```
  The symlink `pi/agent/extensions/pi-monitor-heartbeat` expects pi-monitor to live at `~/Projects/pi-monitor`. Adjust the symlink target if you clone elsewhere.

## Notes on `pi/agent/`

Tracked: `AGENTS.md`, `APPEND_SYSTEM.md`, `settings.json`, `package.json`, `skills/`, `extensions/`, `templates/`, `bin/`, `notes/`, `research/`.

Ignored (see `pi/agent/.gitignore`): `auth.json` (credentials), `sessions/`, `run-history.jsonl`, `.heartbeats/`, `.ruff_cache/`, `node_modules/`, `pi-crash.log`, `bin/fd` (installable binary).

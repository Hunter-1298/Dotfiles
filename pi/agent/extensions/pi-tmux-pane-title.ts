import type {
	ExtensionAPI,
	ExtensionContext,
	SessionEntry,
} from "@mariozechner/pi-coding-agent";

// Companion to pi-tmux-window-name.
// Reads the window name that plugin persists and mirrors it onto a per-pane
// tmux *user option* (`@pi_pane_label`) via `tmux set-option -p`. Does not
// generate names itself, so no duplicate LLM calls.
//
// Why a user option instead of the built-in pane_title (`select-pane -T`):
// pi-tui clears inline images with a Kitty graphics APC sequence (e.g.
// `ESC _ Ga=d,d=A,q=2 ESC \`, "delete all images"). tmux has no Kitty-graphics
// support, so its APC handler copies that payload straight into pane_title,
// clobbering our name with raw control data like "Ga=d,d=A,q=2". When the
// pane border shows `#{pane_title}`, the name visibly flips between the task
// name and that garbage on every image clear. A `@`-prefixed user option lives
// in a separate namespace the Kitty APC can't reach, so the label never gets
// clobbered and the border (and pi-monitor) read a stable value.
//
// Display requires `set -g pane-border-status top` and a pane-border-format
// that reads `#{@pi_pane_label}` (with a `#{pane_title}` fallback for plain
// shells) in tmux.conf.
//
// pi-tmux-window-name's `/rename` runs as a slash command, outside the agent
// loop, so none of session_start / before_agent_start / turn_end fire when it
// completes. We poll on a slow interval to pick up a re-run `/rename` without
// waiting for the next prompt. The poll compares against our own last-applied
// value in memory and writes only on change, so it's a cheap no-op tick when
// nothing changed (no tmux call at all unless the stored name actually moved).

const WINDOW_NAME_ENTRY_TYPE = "pi-tmux-window-name/window";
const PANE_LABEL_OPTION = "@pi_pane_label";
const POLL_INTERVAL_MS = 500;

function getStoredWindowName(entries: SessionEntry[]): string | undefined {
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (entry.type !== "custom") continue;
		if (entry.customType !== WINDOW_NAME_ENTRY_TYPE) continue;
		if (!entry.data || typeof entry.data !== "object") continue;

		const candidate = (entry.data as Record<string, unknown>).windowName;
		if (typeof candidate !== "string") continue;

		const trimmed = candidate.trim();
		if (trimmed) return trimmed;
	}
	return undefined;
}

export default function paneTitleExtension(pi: ExtensionAPI) {
	if (process.env.PI_TMUX_PANE_TITLE_DISABLED === "1") return;
	// Respect the parent plugin's disable flag so sub-agents stay quiet.
	if (process.env.PI_TMUX_WINDOW_NAME_DISABLED === "1") return;
	if (!process.env.TMUX) return;

	const pane = process.env.TMUX_PANE?.trim();
	if (!pane) return;

	// Last value we wrote to @pi_pane_label for this pane. We are the only
	// writer of this option, so an in-memory copy is authoritative and lets
	// the poll skip the tmux round-trip when nothing changed.
	let lastApplied: string | undefined;

	let pollHandle: NodeJS.Timeout | undefined;

	const apply = async (ctx: ExtensionContext) => {
		const name = getStoredWindowName(ctx.sessionManager.getBranch());
		if (!name || name === lastApplied) return;

		try {
			await pi.exec("tmux", [
				"set-option",
				"-p",
				"-t",
				pane,
				PANE_LABEL_OPTION,
				name,
			]);
			lastApplied = name;
		} catch {
			// tmux unavailable mid-session; nothing to do.
		}
	};

	const startPolling = (ctx: ExtensionContext) => {
		if (pollHandle) return;
		pollHandle = setInterval(() => {
			void apply(ctx);
		}, POLL_INTERVAL_MS);
		// Don't keep the process alive just for this timer.
		pollHandle.unref?.();
	};

	const stopPolling = () => {
		if (!pollHandle) return;
		clearInterval(pollHandle);
		pollHandle = undefined;
	};

	pi.on("session_start", async (_event, ctx) => {
		await apply(ctx);
		startPolling(ctx);
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		await apply(ctx);
	});

	pi.on("turn_end", async (_event, ctx) => {
		await apply(ctx);
	});

	pi.on("session_shutdown", async () => {
		stopPolling();
		// Clear our label so the now-plain shell pane falls back to its own
		// pane_title in the border instead of showing a stale task name.
		try {
			await pi.exec("tmux", [
				"set-option",
				"-p",
				"-u",
				"-t",
				pane,
				PANE_LABEL_OPTION,
			]);
		} catch {
			// tmux already gone; nothing to clean up.
		}
	});
}

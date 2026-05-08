import type {
	ExtensionAPI,
	ExtensionContext,
	SessionEntry,
} from "@mariozechner/pi-coding-agent";

// Companion to pi-tmux-window-name.
// Reads the window name that plugin persists and mirrors it to this pane's
// pane_title via `tmux select-pane -T`. Does not generate names itself, so
// no duplicate LLM calls.
//
// Display requires `set -g pane-border-status top` and a pane-border-format
// that includes `#{pane_title}` in tmux.conf.
//
// pi-tmux-window-name's `/rename` runs as a slash command, outside the agent
// loop, so none of session_start / before_agent_start / turn_end fire when it
// completes. Without polling, a re-run `/rename` would not refresh the pane
// title until the user typed the next prompt. We poll on a slow interval
// (cheap: in-memory comparison + early return when unchanged; tmux exec only
// fires when the stored name actually changes) to close that gap.

const WINDOW_NAME_ENTRY_TYPE = "pi-tmux-window-name/window";
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

	let lastApplied: string | undefined;
	let applyInFlight = false;
	let pollHandle: NodeJS.Timeout | undefined;

	const apply = async (ctx: ExtensionContext) => {
		if (applyInFlight) return;
		const name = getStoredWindowName(ctx.sessionManager.getBranch());
		if (!name) return;
		if (name === lastApplied) return;

		applyInFlight = true;
		try {
			const result = await pi.exec("tmux", [
				"select-pane",
				"-t",
				pane,
				"-T",
				name,
			]);
			if (result.code === 0) {
				lastApplied = name;
			}
		} catch {
			// tmux unavailable mid-session; nothing to do.
		} finally {
			applyInFlight = false;
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
		lastApplied = undefined;
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
	});
}

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
// title until the user typed the next prompt. We poll on a slow interval to
// close that gap, and on each tick re-assert the name only when the live
// pane_title has drifted from it (one cheap `display-message` read; the
// `select-pane` write fires only on drift).
//
// The drift check is also what repairs the title after pi-tui clears inline
// images with a Kitty graphics APC sequence (e.g. `ESC _ Ga=d,d=A,q=2 ESC \`,
// "delete all images"). tmux has no Kitty-graphics support and copies that APC
// payload straight into pane_title, clobbering our name with raw control data
// like "Ga=d,d=A,q=2". Comparing against our own last-applied value (instead
// of the actual title) would miss that external clobber, so the garbage would
// stick until the next `/rename`.

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

	let applyInFlight = false;
	let pollHandle: NodeJS.Timeout | undefined;

	const apply = async (ctx: ExtensionContext) => {
		if (applyInFlight) return;
		const name = getStoredWindowName(ctx.sessionManager.getBranch());
		if (!name) return;

		applyInFlight = true;
		try {
			// Read the live pane title and only re-apply on drift. This both
			// avoids redundant writes when nothing changed AND repairs the title
			// after an external clobber (e.g. pi-tui's Kitty graphics APC, which
			// tmux turns into a pane_title like "Ga=d,d=A,q=2").
			let current: string | undefined;
			try {
				const probe = await pi.exec("tmux", [
					"display-message",
					"-p",
					"-t",
					pane,
					"#{pane_title}",
				]);
				if (probe.code === 0) current = (probe.stdout ?? "").trim();
			} catch {
				// Couldn't read the title; fall through and (re)apply anyway.
			}
			if (current === name) return;

			await pi.exec("tmux", ["select-pane", "-t", pane, "-T", name]);
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

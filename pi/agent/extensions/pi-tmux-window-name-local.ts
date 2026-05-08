// Local replacement for the upstream `pi-tmux-window-name` npm package.
//
// Behaves the same as upstream (auto-name + /rename command + tmux window
// rename), but the WINDOW slot uses a "<feature>: <description>" shape.
// Living in `.pi/agent/extensions/` so the customization travels with
// dotfiles and survives `npm update -g`.
//
// Companion `pi-tmux-pane-title.ts` is unchanged: it reads the same
// `pi-tmux-window-name/window` session entry and mirrors it onto the pane
// title, so we keep that entry-type string identical to upstream.
//
// To restore the upstream package: re-add `"npm:pi-tmux-window-name"` to
// `settings.json` `packages` and delete this file.

// `@mariozechner/pi-ai` is provided to extensions at runtime by pi's jiti
// loader (via virtualModules / aliases — see pi-coding-agent's
// extensions/loader.js). Standalone tsc / editors can't resolve it; the
// minimal surface we use is declared in `pi-runtime-shims.d.ts` next to
// this file.
import { completeSimple, type UserMessage } from "@mariozechner/pi-ai";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
	ExtensionContext,
	SessionEntry,
} from "@mariozechner/pi-coding-agent";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// Legacy window-name caps, used only for fallback paths that still operate
// on plain (no-colon) strings (e.g. recovering a window name from the
// session name when no stored window entry exists).
const WINDOW_WORD_MIN = 3;
const WINDOW_WORD_MAX = 4;

// Caps for the new "<feature>: <description>" window shape.
const WINDOW_FEATURE_WORD_MIN = 1;
const WINDOW_FEATURE_WORD_MAX = 3;
const WINDOW_DESC_WORD_MIN = 3;
const WINDOW_DESC_WORD_MAX = 8;

const SESSION_WORD_MIN = 8;
const SESSION_WORD_MAX = 12;
const SESSION_CHAR_MAX = 96;
const REQUEST_TIMEOUT_MS = 30_000;
const NAMING_SOURCE_CHAR_MAX = 4000;

// Keep the entry type identical to upstream so the pane-title companion
// keeps mirroring our window names without changes.
const WINDOW_NAME_ENTRY_TYPE = "pi-tmux-window-name/window";

const DISABLE_ENV_VAR = "PI_TMUX_WINDOW_NAME_DISABLED";
const TRUE_VALUES = new Set(["1", "true", "yes", "on"]);

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type NamingSource = "user_message" | "conversation";
type RenameFailureReason =
	| "missing_prompt"
	| "missing_model"
	| "missing_auth"
	| "request_failed"
	| "invalid_output"
	| "skipped"
	| "stale_session";

type GeneratedNames = {
	windowName: string;
	sessionName: string;
};

type GenerateNamesResult =
	| { ok: true; names: GeneratedNames }
	| {
			ok: false;
			reason: Exclude<RenameFailureReason, "skipped" | "stale_session">;
	  };

type RenameResult =
	| { ok: true; names: GeneratedNames }
	| {
			ok: false;
			reason: RenameFailureReason;
	  };

type TmuxExecResult = { code: number; stdout?: string };
type TmuxExec = (command: string, args: string[]) => Promise<TmuxExecResult>;

// ---------------------------------------------------------------------------
// Prompt
// ---------------------------------------------------------------------------

const WINDOW_AND_SESSION_PROMPT = `You generate names for coding sessions.

Return exactly two lines:
WINDOW: <feature>: <description>
SESSION: <8-12 words>

Window rules:
- Shape is exactly "<feature>: <description>" with one colon and one space between them.
- Feature is 1-3 words naming the area being changed (e.g. "Chat UI", "Auth", "OAuth callback", "DB schema"). Keep proper nouns and acronyms in their natural case.
- Description is 3-8 words explaining what is being updated, in sentence case.
- The colon between feature and description is the only punctuation in the window line.
- Plain letters, numbers, and spaces otherwise. No quotes, markdown, emojis, hyphens, or extra punctuation.

Session rules:
- 8-12 words specific to the user's task.
- Plain letters and numbers, spaces between words. No punctuation.
- Sentence case (capitalize only the first word unless a word is already mixed-case or all caps).
- Descriptive enough for quickly scanning a session list.

General rules:
- No labels beyond WINDOW:/SESSION:, no explanations, no extra lines.

Examples:
WINDOW: Chat UI: fix streamed message ordering
SESSION: Fix ordering of streamed assistant messages in chat UI
WINDOW: OAuth: validate callback retries
SESSION: Implement OAuth callback validation and retry flow in auth service`;

// ---------------------------------------------------------------------------
// Disable / tmux helpers (inlined from upstream disable.ts + tmux-window-target.ts)
// ---------------------------------------------------------------------------

function isExtensionDisabled(env: NodeJS.ProcessEnv = process.env): boolean {
	const value = env[DISABLE_ENV_VAR]?.trim().toLowerCase();
	if (!value) return false;
	return TRUE_VALUES.has(value);
}

function normalizeTarget(value: string | undefined): string | undefined {
	const target = value?.trim();
	return target || undefined;
}

function buildRenameWindowArgs(name: string, target?: string): string[] {
	return target ? ["rename-window", "-t", target, name] : ["rename-window", name];
}

async function resolveTmuxWindowTarget(
	exec: TmuxExec,
	env: NodeJS.ProcessEnv = process.env,
): Promise<string | undefined> {
	if (!env.TMUX) return undefined;

	const pane = normalizeTarget(env.TMUX_PANE);
	if (!pane) return undefined;

	try {
		const result = await exec("tmux", ["display-message", "-p", "-t", pane, "#{window_id}"]);
		if (result.code !== 0) return undefined;
		return normalizeTarget(result.stdout);
	} catch {
		return undefined;
	}
}

// ---------------------------------------------------------------------------
// String validators
// ---------------------------------------------------------------------------

function normalizeWords(value: string): string[] {
	return value
		.replace(/[\n\r\t]+/g, " ")
		.replace(/["'`“”‘’]/g, " ")
		.replace(/[^A-Za-z0-9\s-]/g, " ")
		.replace(/[-_]+/g, " ")
		.split(/\s+/)
		.map((word) => word.trim())
		.filter(Boolean);
}

function compactWindowName(value: string, minWords = WINDOW_WORD_MIN): string | undefined {
	const words = normalizeWords(value).slice(0, WINDOW_WORD_MAX);
	if (words.length < minWords) return undefined;
	const name = words.join(" ").trim();
	return name || undefined;
}

function compactFeatureWindowName(value: string): string | undefined {
	const cleaned = cleanGeneratedValue(value);
	if (!cleaned) return undefined;

	const colonIdx = cleaned.indexOf(":");
	if (colonIdx <= 0) return undefined;

	const featureRaw = cleaned.slice(0, colonIdx);
	const descRaw = cleaned.slice(colonIdx + 1);

	const featureWords = normalizeWords(featureRaw).slice(0, WINDOW_FEATURE_WORD_MAX);
	if (featureWords.length < WINDOW_FEATURE_WORD_MIN) return undefined;

	const descWords = normalizeWords(descRaw).slice(0, WINDOW_DESC_WORD_MAX);
	if (descWords.length < WINDOW_DESC_WORD_MIN) return undefined;

	return `${featureWords.join(" ")}: ${descWords.join(" ")}`;
}

function compactSessionName(value: string, minWords = SESSION_WORD_MIN): string | undefined {
	const words = normalizeWords(value).slice(0, SESSION_WORD_MAX);
	if (words.length < minWords) return undefined;

	while (words.length > minWords && words.join(" ").length > SESSION_CHAR_MAX) {
		words.pop();
	}

	const name = words.join(" ").trim();
	if (!name) return undefined;
	if (name.length <= SESSION_CHAR_MAX) return name;
	return name.slice(0, SESSION_CHAR_MAX).trim() || undefined;
}

function cleanGeneratedValue(value: string): string {
	return value.replace(/^[\s"'`]+|[\s"'`]+$/g, "").trim();
}

function parseGeneratedNames(value: string): { window?: string; session?: string } {
	const lines = value
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter(Boolean);

	let windowName: string | undefined;
	let sessionName: string | undefined;

	for (const line of lines) {
		if (!windowName) {
			const windowMatch = line.match(/window\s*:\s*(.*?)(?=\bsession\s*:|$)/i);
			if (windowMatch?.[1]) {
				windowName = cleanGeneratedValue(windowMatch[1]);
			}
		}

		if (!sessionName) {
			const sessionMatch = line.match(/session\s*:\s*(.*)$/i);
			if (sessionMatch?.[1]) {
				sessionName = cleanGeneratedValue(sessionMatch[1]);
			}
		}

		if (windowName && sessionName) break;
	}

	return { window: windowName, session: sessionName };
}

// ---------------------------------------------------------------------------
// Session entry helpers
// ---------------------------------------------------------------------------

function getStoredWindowName(entries: SessionEntry[]): string | undefined {
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (entry.type !== "custom") continue;
		if (entry.customType !== WINDOW_NAME_ENTRY_TYPE) continue;
		if (!entry.data || typeof entry.data !== "object") continue;

		const candidate = (entry.data as Record<string, unknown>).windowName;
		if (typeof candidate !== "string") continue;

		// Stored window names were already validated when written; just trim so
		// the "<feature>: <description>" colon survives round-trips.
		const trimmed = candidate.trim();
		if (trimmed) return trimmed;
	}
	return undefined;
}

function extractTextFromMessageContent(content: unknown): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";

	return content
		.filter(
			(part): part is { type: "text"; text: string } =>
				!!part &&
				typeof part === "object" &&
				"type" in part &&
				part.type === "text" &&
				"text" in part,
		)
		.map((part) => part.text.trim())
		.filter(Boolean)
		.join("\n")
		.trim();
}

function getFirstUserPrompt(entries: SessionEntry[]): string | undefined {
	for (const entry of entries) {
		if (entry.type !== "message") continue;
		if (entry.message.role !== "user") continue;

		const text = extractTextFromMessageContent(entry.message.content);
		if (text) return text;
	}
	return undefined;
}

function buildConversationNamingSource(entries: SessionEntry[]): string | undefined {
	const messages: string[] = [];

	for (const entry of entries) {
		if (entry.type !== "message") continue;

		const role = entry.message.role;
		if (role !== "user" && role !== "assistant") continue;

		const text = extractTextFromMessageContent(entry.message.content);
		if (!text) continue;

		messages.push(`<${role}>\n${text}\n</${role}>`);
	}

	const conversation = messages.join("\n\n").trim();
	return conversation || undefined;
}

function formatNamingPrompt(seed: string, source: NamingSource): string {
	const tag = source === "conversation" ? "conversation" : "user_message";
	const content = seed.trim().slice(0, NAMING_SOURCE_CHAR_MAX);

	return `<${tag}>\n${content}\n</${tag}>\n\nRespond now using exactly this format:\nWINDOW: <feature>: <description>\nSESSION: 8-12 words`;
}

// ---------------------------------------------------------------------------
// Tmux + LLM
// ---------------------------------------------------------------------------

async function renameCurrentTmuxWindow(
	pi: ExtensionAPI,
	name: string,
	targetWindow?: string,
): Promise<boolean> {
	if (!process.env.TMUX) return false;

	try {
		const result = await pi.exec("tmux", buildRenameWindowArgs(name, targetWindow));
		return result.code === 0;
	} catch {
		return false;
	}
}

async function generateNames(
	prompt: string,
	source: NamingSource,
	ctx: ExtensionContext,
): Promise<GenerateNamesResult> {
	const seed = prompt.trim();
	if (!seed) return { ok: false, reason: "missing_prompt" };

	if (!ctx.model) return { ok: false, reason: "missing_model" };

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
	if (!auth.ok) return { ok: false, reason: "missing_auth" };

	const message: UserMessage = {
		role: "user",
		content: [{ type: "text", text: formatNamingPrompt(seed, source) }],
		timestamp: Date.now(),
	};

	const controller = new AbortController();
	const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

	let response;
	try {
		response = await completeSimple(
			ctx.model,
			{
				systemPrompt: WINDOW_AND_SESSION_PROMPT,
				messages: [message],
			},
			{
				apiKey: auth.apiKey,
				headers: auth.headers,
				maxTokens: 96,
				signal: controller.signal,
			},
		);
	} catch {
		return { ok: false, reason: "request_failed" };
	} finally {
		clearTimeout(timeoutId);
	}

	const generated = response.content
		.filter((part): part is { type: "text"; text: string } => part.type === "text")
		.map((part) => part.text)
		.join("\n");

	const parsed = parseGeneratedNames(generated);
	const windowName = compactFeatureWindowName(parsed.window ?? "");
	const sessionName = compactSessionName(parsed.session ?? "");

	if (!windowName || !sessionName) {
		return { ok: false, reason: "invalid_output" };
	}

	return { ok: true, names: { windowName, sessionName } };
}

function describeRenameFailure(reason: RenameFailureReason): string {
	switch (reason) {
		case "missing_prompt":
			return "No user or assistant text found in the current branch.";
		case "missing_model":
			return "No active model is selected for generating a session name.";
		case "missing_auth":
			return "No request auth is available for the active model.";
		case "request_failed":
			return "Session rename request failed.";
		case "invalid_output":
			return "The model returned an invalid session name format.";
		case "stale_session":
			return "Session changed before rename completed.";
		case "skipped":
			return "Session rename was skipped.";
	}
}

function notify(
	ctx: ExtensionContext | ExtensionCommandContext,
	message: string,
	level: "info" | "error",
) {
	if (!ctx.hasUI) return;
	ctx.ui.notify(message, level);
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function tmuxWindowNameLocalExtension(pi: ExtensionAPI) {
	if (isExtensionDisabled()) return;

	let hasNameForSession = false;
	let hasAttemptedNameForSession = false;
	let renameInFlight: Promise<RenameResult> | null = null;
	let sessionEpoch = 0;
	let tmuxWindowTarget: string | undefined;
	let tmuxWindowTargetInFlight: Promise<string | undefined> | null = null;

	const resetSessionState = () => {
		sessionEpoch += 1;
		hasNameForSession = false;
		hasAttemptedNameForSession = false;
		renameInFlight = null;
		tmuxWindowTarget = undefined;
		tmuxWindowTargetInFlight = null;
	};

	const captureTmuxWindowTarget = async (): Promise<string | undefined> => {
		if (tmuxWindowTarget) return tmuxWindowTarget;
		if (tmuxWindowTargetInFlight) return tmuxWindowTargetInFlight;

		const work = resolveTmuxWindowTarget((command, args) => pi.exec(command, args))
			.then((target) => {
				tmuxWindowTarget = target;
				return target;
			})
			.finally(() => {
				if (tmuxWindowTargetInFlight === work) {
					tmuxWindowTargetInFlight = null;
				}
			});

		tmuxWindowTargetInFlight = work;
		return work;
	};

	const persistNames = async (names: GeneratedNames, targetWindow?: string) => {
		pi.setSessionName(names.sessionName);
		pi.appendEntry(WINDOW_NAME_ENTRY_TYPE, { windowName: names.windowName });
		await renameCurrentTmuxWindow(pi, names.windowName, targetWindow);
		hasNameForSession = true;
		hasAttemptedNameForSession = true;
	};

	const runRename = async (
		prompt: string | undefined,
		source: NamingSource,
		ctx: ExtensionContext,
		options?: { force?: boolean },
	): Promise<RenameResult> => {
		const force = options?.force ?? false;

		if (!force && (hasNameForSession || hasAttemptedNameForSession || renameInFlight)) {
			return { ok: false, reason: "skipped" };
		}

		const seed = prompt?.trim();
		if (!seed) return { ok: false, reason: "missing_prompt" };

		if (!force) hasAttemptedNameForSession = true;

		const currentEpoch = sessionEpoch;
		const work = (async (): Promise<RenameResult> => {
			const targetWindow = await captureTmuxWindowTarget();
			const result = await generateNames(seed, source, ctx);
			if (!result.ok) return result;

			if (currentEpoch !== sessionEpoch) {
				return { ok: false, reason: "stale_session" };
			}

			await persistNames(result.names, targetWindow);
			return { ok: true, names: result.names };
		})();

		const inFlight = work.finally(() => {
			if (renameInFlight === inFlight) renameInFlight = null;
		});

		renameInFlight = inFlight;
		return inFlight;
	};

	const applyAutoName = async (
		seedPrompt: string | undefined,
		ctx: ExtensionContext,
	): Promise<void> => {
		const targetWindow = await captureTmuxWindowTarget();
		const existing = pi.getSessionName();
		if (existing) {
			const restoredWindow =
				getStoredWindowName(ctx.sessionManager.getBranch()) ??
				compactWindowName(existing, 1) ??
				existing;
			await renameCurrentTmuxWindow(pi, restoredWindow, targetWindow);
			hasNameForSession = true;
			hasAttemptedNameForSession = true;
			return;
		}

		await runRename(seedPrompt, "user_message", ctx);
	};

	const restoreExistingSessionName = async (ctx: ExtensionContext) => {
		const existing = pi.getSessionName();
		if (!existing) return;

		const targetWindow = await captureTmuxWindowTarget();
		const storedWindow = getStoredWindowName(ctx.sessionManager.getBranch());
		const windowName = storedWindow ?? compactWindowName(existing, 1) ?? existing;
		await renameCurrentTmuxWindow(pi, windowName, targetWindow);
		hasNameForSession = true;
		hasAttemptedNameForSession = true;
	};

	const renameFromBranch = async (args: string, ctx: ExtensionCommandContext) => {
		if (args.trim()) {
			notify(ctx, "/rename does not take arguments", "error");
			return;
		}

		await ctx.waitForIdle();

		if (renameInFlight) await renameInFlight;

		const conversation = buildConversationNamingSource(ctx.sessionManager.getBranch());
		const result = await runRename(conversation, "conversation", ctx, { force: true });

		if (!result.ok) {
			notify(ctx, describeRenameFailure(result.reason), "error");
			return;
		}

		notify(ctx, `Renamed session: ${result.names.sessionName}`, "info");
	};

	pi.registerCommand("rename", {
		description: "Rename the current session from user and assistant messages in this branch",
		handler: renameFromBranch,
	});

	pi.on("session_start", async (_event, ctx) => {
		resetSessionState();
		await restoreExistingSessionName(ctx);
	});

	pi.on("before_agent_start", async (event, ctx) => {
		const firstPrompt = getFirstUserPrompt(ctx.sessionManager.getBranch()) ?? event.prompt;

		if (ctx.hasUI) {
			void applyAutoName(firstPrompt, ctx);
			return;
		}

		await applyAutoName(firstPrompt, ctx);
	});
}

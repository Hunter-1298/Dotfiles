// Ambient declarations for packages that pi's extension loader provides at
// runtime via jiti aliases / virtualModules but that aren't reachable through
// `.pi/agent/node_modules/`. See pi-coding-agent's `core/extensions/loader.js`
// (`getAliases()` / `VIRTUAL_MODULES`) for the canonical list.
//
// Only the surface area actually used by local extensions is declared here.
// Add more as needed. Mirrors the relevant types from
// `@mariozechner/pi-ai/dist/types.d.ts` and `dist/stream.d.ts`.

declare module "@mariozechner/pi-ai" {
	export type UserMessage = {
		role: "user";
		content: Array<{ type: "text"; text: string }>;
		timestamp?: number;
	};

	export interface Context {
		systemPrompt?: string;
		messages: UserMessage[];
		tools?: unknown[];
	}

	export interface SimpleStreamOptions {
		apiKey?: string;
		headers?: Record<string, string>;
		maxTokens?: number;
		signal?: AbortSignal;
	}

	export interface AssistantMessage {
		role: "assistant";
		content: Array<
			{ type: "text"; text: string } | { type: string; [key: string]: unknown }
		>;
		timestamp?: number;
	}

	export function completeSimple(
		model: unknown,
		context: Context,
		options?: SimpleStreamOptions,
	): Promise<AssistantMessage>;
}

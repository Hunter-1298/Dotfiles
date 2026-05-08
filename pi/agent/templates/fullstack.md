# AGENTS.md

This project is a full-stack app: Python/FastAPI backend, Next.js/React/TypeScript frontend, with AI features layered on top.

The global AGENTS.md (no fake work, plan-before-implement, disclosure, function limits, communication style) applies to everything below. Stack-specific rules here extend it; they do not replace it.

## Backend (Python / FastAPI)

- Type hints on every function signature and Pydantic model field.
- Route handlers stay thin: parse input → call service → shape response. Business logic lives in services or domain modules, not in routes.
- Database access lives behind a service or repository layer. Never call the DB from inside a route handler.
- Prefer Pydantic models over dicts for any data crossing a boundary (HTTP, DB, queue, external API).
- One consistent error response shape across the API. Don't invent a new shape per route.
- When you add a route, also wire it into the router and update OpenAPI tags if relevant.

## Frontend (Next.js / React / TypeScript)

- TypeScript strict mode. No `any` without a one-line comment explaining why.
- Default to server components. Add `"use client"` only when state, effects, or browser APIs are needed.
- Components stay focused on rendering. Data fetching and side effects go into hooks or server components.
- Always render explicit loading, error, and empty states for any async data.
- If a component approaches ~150 lines OR has more than two distinct responsibilities, split it.

## AI features

- Prompt construction lives in its own module, separate from the API call. Version prompts by file or by an explicit `PROMPT_VERSION` constant in the same module.
- Validate model inputs before sending. Parse model outputs defensively — treat the model as untrusted.
- Prefer structured outputs (JSON mode, Pydantic schemas, tool-call schemas) over freeform text whenever possible.
- Every AI call has explicit timeout and retry behavior. No naked `await client.complete(...)`.
- Log inputs and outputs at debug level with secrets redacted. Never log full API keys, raw auth tokens, or unscrubbed user PII.
- AI features must degrade gracefully — define what "no AI available" looks like for each feature and implement that path.

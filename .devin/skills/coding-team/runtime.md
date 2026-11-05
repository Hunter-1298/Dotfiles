# Devin runtime — role delegation

Use this binding instead of `adapters/codex/runtime.md`. The role cards and core policies come from the bundled upstream checkout; the tools, profiles, permissions, and task boundaries come from the active Devin session.

## Authorization

Only delegate when the user has explicitly requested a team or subagents for the current task. Installation, automatic skill activation, and a repository instruction to load the skill are not themselves permission to spawn workers. If authorization is absent, ask. If inline work is chosen, state that it does not provide independent team review.

## Role mapping

Role names are assignments in the worker prompt, not Devin profile identifiers.

| Canonical role | Devin profile | Scope |
|---|---|---|
| `investigator` | `subagent_explore` | Read-only discovery with file and line evidence |
| `advisor` | `subagent_explore` | Read-only technical direction before implementation |
| `contradictor` | `subagent_explore` | Read-only challenge, serial after Advisor |
| `product-manager` | `subagent_explore` | Scope and acceptance analysis; questions return to Lead |
| `domain-advisor` | `subagent_explore` | Named-domain consultation using the upstream template |
| `system-architect` | `subagent_general` | One named contract only when writing it is authorized |
| `backend-engineer` | `subagent_general` | Implementation in exclusively assigned paths |
| `frontend-builder` | `subagent_general` | UI implementation under the approved design contract |
| `frontend-ux-lead` | `subagent_explore` for analysis; `subagent_general` for authorized writes | UX direction with explicit write scope |
| `docs-steward` | `subagent_general` | Only named, authorized documentation changes |
| `test-engineer` | `subagent_general` | Only permitted focused checks and evidence |
| `gatekeeper` | `subagent_explore` | Read-only decision after Test Engineer finishes |
| `lead` | Parent session | Scope, briefs, coordination, and human gates |

Use only profiles actually available in the session. If a task requires capabilities its profile lacks, split the task or report the limitation rather than inventing tool access. `subagent_explore` cannot run shell commands or edit files. A Test Engineer using `subagent_general` must receive explicit write restrictions even though the profile has broader capabilities.

## Dispatch and results

- Use `run_subagent` with `title`, `task`, `profile`, and `is_background`. There are no per-call `model` or `effort` arguments; do not simulate them through prompt text.
- Use foreground execution when the result is needed before continuing or tool approvals are likely. Only one foreground worker can run at a time.
- For genuinely independent work, launch background workers before any foreground worker. Keep at most two workers active and their writable paths disjoint.
- Background workers cannot request unapproved tool permissions. Do not change permissions to work around this; bring the task back to Lead for the appropriate decision.
- Receive completion notifications or use `read_subagent` with the returned agent ID. Do not poll in a loop.
- Test Engineer must finish before Gatekeeper starts. Advisor and Contradictor are also sequential when that debate is required.
- Never overlap Gatekeeper with an implementer. Do not ask workers to spawn nested agents.
- Return incomplete or blocked output to the human under the upstream approval gates. Never report an unrun test or review as complete.

## Prompt packet

Provide a concise, self-contained brief with:

1. Canonical role and absolute path to its role card.
2. Resolved `CODING_TEAM_ROOT` and the actual project or worktree path.
3. Objective, acceptance criteria, relevant context, and evidence pointers.
4. Exclusive write paths, read scope, and explicit prohibited actions.
5. Applicable user and project rules, including testing limits, design requirements, approval gates, and relevant skills.
6. Exact permitted verification commands and a clear stop condition.
7. Expected result: changed paths, evidence, limitations, and any decision required.

Workers do not inherit the conversation. Pass relevant constraints explicitly and have them read named source files; do not assume they know the user's request. Keep summaries concise and never manufacture model identities, approvals, or independent validation.

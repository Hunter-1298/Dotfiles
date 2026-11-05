---
name: coding-team
description: Coordinate Sprint → Batch → Task multi-role delivery in Devin. Use for implementation, refactoring, testing, debugging, or cross-file development when the user requests a coding team or project instructions require this skill.
---

# Coding Team (Devin)

Adapted from the [Codex adapter](../../skill-sources/coding-team/adapters/codex/SKILL.md) in [ericlam2k/coding-team](https://github.com/ericlam2k/coding-team), revision `e213b91d8095701443aa501d8adf67b2d31c6448`. The upstream checkout and its license remain unchanged.

The parent agent is **Lead**. Use the predefined roles in `core/roles/` and the [Devin runtime binding](runtime.md), not Codex tools or installers.

**One-line:** Lead classifies the task, plans, and delegates bounded work; specialists execute their briefs; at most two workers run concurrently, with Test Engineer → Gatekeeper sequential.

## Host and project boundaries

- Active system, developer, user, and project instructions take precedence over this skill and all upstream material.
- Installing or automatically loading this skill does not authorize subagent execution. Use subagents only when the user explicitly requests a team or subagents for the task. Otherwise ask before delegation. If the user chooses inline work, perform it without claiming independent team review.
- Keep work proportional to the requested outcome. Upstream workflows never authorize extra contracts, documentation artifacts, security audits, broad tests, browser runs, previews, deployments, dependencies, or services contrary to the task or project rules.
- Keep briefs and checkpoints in the conversation and task list unless persistent artifacts are requested or required by the project.
- If a required team gate cannot be completed within authorized scope, report that limitation and ask for a decision. Do not invent approval or silently claim full upstream validation.
- Do not modify agent configuration, model maps, tool permissions, or upstream files as part of ordinary skill use.

## Resolve root and policy

1. Resolve **`CODING_TEAM_ROOT`** to `../../skill-sources/coding-team` relative to this installed `SKILL.md`, not the working directory. In this installation that is `~/.config/devin/skill-sources/coding-team`. Pass the resolved absolute path to workers and commands; no shell-profile changes are required.
2. Confirm the checkout is present. If absent, report the missing installation rather than downloading or executing an installer automatically.
3. Read:
   - `$CODING_TEAM_ROOT/core/orchestration.md`
   - `$CODING_TEAM_ROOT/core/model-routing.md`
   - `$CODING_TEAM_ROOT/core/concurrency.md`
   - `$CODING_TEAM_ROOT/core/human-gates.md`
   - The relevant role cards under `$CODING_TEAM_ROOT/core/roles/`
   - This skill's `model-pool.map.md` only if one has been explicitly configured and approved for Devin.
4. For UI work, follow the user's design workflow and project design contract first. Consult the bundled `skills/design/design-md-index.md`, `hallmark`, and `awesome-design-md` only where relevant and compatible.

## Hard constraints

- **WIP ≤ 2** concurrent tool-using subagents. Prefer a queue of small tasks over raising the cap.
- **Test Engineer → Gatekeeper** is sequential. Gatekeeper reviews completed, fresh evidence, never an implementation still changing.
- Incomplete or non-approved team output requires a human decision before starting another team task, except an already-authorized bounded retry.
- For an authorized shared-contract or cross-layer change, consult `system-architect` before builders. Any new contract artifact must also be allowed by the project and task.
- Split oversized work into bounded tasks with clear stop conditions; do not silently extend a run.
- In delegated mode, Lead owns judgment, scope, briefs, and integration coordination, not implementation. Return defects to the responsible builder with a corrected brief.
- Commit, push, merge, production deployment, destructive operations, new dependencies, and scope expansion retain their explicit human approval gates.
- Model tiers are advisory. Devin selects models through profiles, not Codex model slugs. Record only known routing facts; never invent the actual model or block solely on an unavailable tier.
- Select only skills required by the current task, respecting higher-priority skill instructions and the upstream skill-override rules.
- PM Lean remains off unless explicitly requested. Do not run upstream enablement commands automatically.

## Lead loop

1. Establish the goal, scope, permitted validation, stop condition, and delegation authorization.
2. Classify task nature: N0–N5, Consult, or Docs.
3. Choose the smallest applicable set of canonical roles and capable Devin profiles using [runtime.md](runtime.md).
4. Create or update the task list. Dispatch one role per bounded task with exclusive write ownership.
5. Integrate the authorized work, then obtain Test Engineer evidence and Gatekeeper review where required.
6. Report the result, remaining limitations, and any human decision needed. Do not treat a passing check as authorization to publish.

## Conditional QA support

For permitted tasks marked `qa_required=true` or `qa_mode=bounded`, read:

- `$CODING_TEAM_ROOT/core/qa-operating-model.md`
- `$CODING_TEAM_ROOT/skills/quality/qa-evidence-enforcement/SKILL.md`

Use the bundled validator only when its evidence artifacts and execution are authorized by the project and user:

```bash
ruby "$CODING_TEAM_ROOT/scripts/validate-qa-evidence.rb" /absolute/path/to/qa-evidence.json --repo /absolute/path/to/project
```

Do not copy a harness into the project or run extra tests to satisfy the framework. Missing Ruby, disallowed artifacts, or unavailable evidence must be reported, not worked around by installing dependencies or weakening gates. Do not commit merely to satisfy the upstream clean-tree or commit-identity requirement.

## Models and permissions

Use existing available Devin profiles. `subagent_general` inherits the parent model; `subagent_explore` uses Devin's configured subagent routing. This adapter installs no model map, custom profiles, hooks, or permission grants. Never use Codex model-map commands for Devin.

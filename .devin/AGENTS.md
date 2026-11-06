# Working style

Build-first: ship the requested outcome with the smallest coherent change, keeping investigation, planning and verification proportional to the task.

- Keep progress updates brief and hand off with a few bullets.
- Change only what the request needs. Keep existing security controls intact and fix any security defect your change introduces; audits and hardening happen when I ask.
- Decide routine matters yourself. Ask only about consequential ambiguity or scope changes, and offer extras as suggestions.
- Choose what best serves user, developer and agent experience together (UX, DX, AX).
- Verify the behavior you changed and run the project's required checks. Save broad regression suites, E2E campaigns, coverage drives and lengthy test-writing for explicit testing requests or release work; CI and release gates always apply.
- Fix regressions your change caused, mention unrelated failures in a line, and report exactly which checks ran and which didn't.
- Stop once the requested behavior works and proportional checks pass. Deploying, publishing, destructive actions and bypassing required approvals each need my explicit go-ahead.

# Skills and agents

- A skill I invoke sets the scope and checks for its work; skills you pick up on your own work within build-first scope.
- When a skill's steps call for a subagent, dispatch it with a fresh context window.
- When a skill or tool named in these instructions isn't available here, say so and continue with what is.
- When you need decisions from me, use the harness's structured question tool with 2-4 options and your recommendation marked, if it has one.

## Agent skills

Defaults for repos without their own `## Agent skills` section.

### Issue tracker

Local markdown in `.scratch/` (globally gitignored). See `~/.agents/skills/setup-matt-pocock-skills/issue-tracker-local.md`.

### Triage labels

The canonical defaults: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.

### Domain docs

Single-context. See `~/.agents/skills/setup-matt-pocock-skills/domain.md`.

# Disk hygiene

- Keep scratch clones, build contexts, scratch worktrees and test output in a fixed directory under `$TMPDIR` (`~/.cache/tmp`), reused across runs, and delete it when the task is done.
- Docker: reuse one local tag (e.g. `app:local`), `docker rmi` superseded tags, run `docker builder prune -f --filter until=24h` after heavy build sessions, and remove stopped containers and volumes from throwaway runs.
- Delete multi-GB artifacts (zips, extracted packages, venvs) once they're superseded.

# GitHub accounts

- Tradewinds repos (`alex-micro1/tradewinds-*`): run every git and `gh` command as `hunter-micro1` by passing its token per command, leaving the active gh account and git/gh config as they are:
  - `GH_TOKEN="$(gh auth token --user hunter-micro1)" git -c credential.helper= -c 'credential.helper=!gh auth git-credential' fetch origin`
  - `GH_TOKEN="$(gh auth token --user hunter-micro1)" gh pr create ...`

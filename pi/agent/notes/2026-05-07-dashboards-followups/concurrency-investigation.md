# Concurrency hazard during PR #177 — investigation

## TL;DR

Two `pi` agent sessions are alive on the contract repo right now. Each owns a
distinct auto-worktree, exactly as the extension intended. The collision was
**not** an extension bug — a prior worker in the parent session (me, in the
turns leading up to PR #177) navigated _into the other session's worktree_
via `cd` and ran destructive git operations there. The two sessions then
fought over the same files. Fix is a usage rule, not an extension change.

## 1. What the auto-worktree extension actually does

Source: `/home/hshayde/.pi/agent/extensions/auto-worktree.ts` (~150 LOC).

When `pi` launches, the extension runs **once** before `session_start`:

| Condition                                                           | Action                                                                                                                                                                                                         |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PI_WORKTREE_ALREADY=1` set                                         | Skip — we're the re-exec'd child                                                                                                                                                                               |
| Not in a git repo                                                   | Skip                                                                                                                                                                                                           |
| Detached HEAD                                                       | Skip                                                                                                                                                                                                           |
| `.git` at toplevel is a regular file (already in a linked worktree) | Skip                                                                                                                                                                                                           |
| Otherwise                                                           | Create worktree at `<parent>/<repo>-<branch>-<ts>` on `agent/<branch>-<ts>`, then `spawnSync("pi", argv, {cwd: worktreeDir, env: {...env, PI_WORKTREE_ALREADY:"1"}})`, parent waits, exits with child's status |

Timestamp granularity is **seconds** (`YYYYMMDD-HHMMSS`). Two `pi` launches
in the same second would collide on path/branch — possible but not what
happened here (timestamps are minutes apart).

The extension only runs at session start. **It cannot prevent a session from
later cd'ing into a different worktree** and editing files there.

## 2. Live worktrees (contract repo)

`git worktree list` shows 20 contract-related worktrees. The two relevant ones:

| Worktree                              | Current branch                           | Owning pi PID                        |
| ------------------------------------- | ---------------------------------------- | ------------------------------------ |
| `contract-hunter-poc-20260506-164557` | `agent/hunter-poc-20260506-164557`       | **534280 (parent of this subagent)** |
| `contract-hunter-poc-20260506-112031` | `agent/hunter-poc-cand6-20260507-125609` | **3386215 (other live session)**     |

The other ~17 contract worktrees are stale (no live pi process attached).
There are also 2 pace-repo worktrees, each with their own pi, plus `dashagent-port`
and `delete-dashboards-sweep` created by recent PR work (no dedicated pi).

## 3. Live pi sessions

From `ps -ef | grep pi`, `/proc/PID/cwd`, and `~/.pi/agent/.heartbeats/`:

| PID         | Parent  | Started     | cwd                                   | Heartbeat session file points to                                               |
| ----------- | ------- | ----------- | ------------------------------------- | ------------------------------------------------------------------------------ |
| 534130      | tmux    | May 6 16:39 | `contract/apps`                       | (auto-worktree wrapper, blocking on child)                                     |
| **534280**  | 534130  | May 6 16:39 | `contract-hunter-poc-20260506-164557` | …`-164557--/…` ← **my parent session**                                         |
| 1555170/1/2 | 534280  | Today 15:25 | `delete-dashboards-sweep` + 164557    | subagents spawned by 534280                                                    |
| 3385978     | tmux    | May 6 11:07 | `contract/apps`                       | (auto-worktree wrapper)                                                        |
| **3386215** | 3385978 | May 6 11:07 | `contract-hunter-poc-20260506-112031` | …`-112031--/…` ← **other live session, currently running `ask_user_question`** |
| 1913637     | 1913530 | May 6 22:07 | `pace-main-20260506-221155`           | pace repo, irrelevant                                                          |
| 2976989     | 2976816 | May 6 10:13 | `pace-main-20260506-102620`           | pace repo, irrelevant                                                          |
| 3750716     | tmux    | May 6 12:08 | `~/.config/pi/agent`                  | settings/config session                                                        |

Both contract sessions (534280 + 3386215) **were correctly isolated at start
by auto-worktree**. Each got its own worktree on its own `agent/` branch.

## 4. Root cause

**Usage error in the parent session (PID 534280), not an extension bug.**

What happened, reconstructed from the conversation history:

1. Session 534280 was correctly placed in worktree `…164557` on its agent branch.
2. PR #169–#173 work involved checking out remote PR branches. Instead of
   fetching them into 534280's own worktree, prior turns ran
   `cd /home/hshayde/.../contract-hunter-poc-20260506-112031` (because the
   relevant branch happened to be checked out there) and did `git stash`,
   `git checkout`, `git commit`, `git push` against that path.
3. That path is the **other live session's** auto-worktree (PID 3386215, a
   long-lived agent session that has been working on a `cand6` candidate
   refactor today).
4. When both sessions had uncommitted edits and one switched branches, files
   went missing / branch state diverged ("git checkout appeared to succeed
   but `git branch --show-current` returned the previous branch", "backend
   edits to 3 files disappeared after stash+pop"). Classic two-writers race.

Why the prior worker drifted into 112031: the PR-checkout flow ergonomically
landed there because `gh pr checkout` had been run there before. There was no
guardrail in this session reminding the agent that `…-112031` belongs to a
different pi.

## 5. Recommended fix

**Don't change the extension.** It is doing its job — strict pre-session
isolation, with documented skip rules. Asking it to police shell access
_during_ a session would mean wrapping every shell call, which breaks the
agent's usefulness.

Two cheap, high-value mitigations on the **agent / workflow** side:

1. **Add a usage rule to `~/.pi/agent/AGENTS.md`** under "Work well with
   others": _Stay inside your own auto-worktree. To bring a remote PR branch
   in, run `git fetch origin <branch>` then `git checkout -b <local> FETCH_HEAD`
   inside your own worktree, **or** create a dedicated worktree with
   `git worktree add`. Never `cd` into another `agent/...-TIMESTAMP` worktree._
2. **At session-start (or first git op), surface the active worktrees**.
   The extension or a thin status hook could log
   `auto-worktree: you own <path>; other live pi sessions own [<path>, ...]`
   by reading `~/.pi/agent/.heartbeats/*.json` + `git worktree list`. That
   one line of context would have prevented this incident.

Optional, lower-priority: bump the timestamp granularity to milliseconds
(`getTime()` instead of seconds) to defend against the rare same-second
double-launch case. Not what bit us this time.

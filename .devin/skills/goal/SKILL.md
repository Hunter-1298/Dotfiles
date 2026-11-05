---
name: goal
description: Run long-running checks with no runtime limit by default, track background processes, and report verified results without stopping at the first tool timeout.
argument-hint: "<objective> [check commands] [optional time budget] [check-only|fix]"
triggers:
  - user
---

# Goal

Treat the user's text following `/goal` as the objective. If no objective is supplied, ask what to check. Pursue the agreed outcome until it is verified, a failure or blocker requires user input, the user cancels, or an explicitly requested limit is reached. Elapsed time alone is not a reason to stop when the user has not set a runtime limit.

This is an inline Devin workflow, not a daemon or scheduler. It requires an active session. A checkpoint preserves progress but does not keep an agent running or automatically restart work after the session ends. Use only tools actually available in the current session.

## Establish the contract

Before starting commands:

1. Read the applicable project rules and discover the real verification commands from project scripts and configuration. Do not invent test commands, flags, environments, or dependencies.
2. State the objective, scope, exact commands and working directories, and evidence that will prove success. All required checks must pass; a passing subset is not completion. For repeated stability checks, define the required number of successful runs and how any failure affects the result.
3. Default to **check-only**. Do not edit source, install dependencies, change configuration, migrate or reset databases, or deploy anything unless the user explicitly authorizes that work. Check commands may still have side effects: inspect unfamiliar scripts and ask before destructive or external changes.
4. Use **unlimited runtime by default**. Set a deadline only if the user explicitly requests one; do not invent a time budget or ask the user to choose one as a prerequisite. Keep **one run per agreed check and no automatic retries** by default. If fixes are explicitly authorized, allow at most **three repair-and-verify rounds** unless the user specifies a different attempt limit; this does not impose a runtime limit. For a watcher or soak test, establish observation cadence and success or failure criteria, with a finite observation window only if requested by the user.
5. Briefly announce the contract. Ask a focused question only when a missing detail materially changes scope, safety, or the meaning of success.

A skill invocation does not expand permissions. Keep normal tool approvals and all repository, organization, classification, and security rules intact. Never weaken checks, skip failures, disable guardrails, or change compliance controls to produce a passing result. Do not use subagents unless the user explicitly requests them.

## Execute and monitor

- Track the work with `todo_write`, keeping exactly one item in progress and marking completion only after observing the required evidence.
- Record the start time. Record and enforce a deadline only when the user explicitly supplies a runtime limit. Otherwise keep monitoring without an elapsed-time cap.
- Run independent checks concurrently only when they do not contend over shared databases, generated files, caches, ports, or other mutable state. Otherwise run them sequentially.
- Launch each command once with `exec`, using the verified working directory. For a known long-running command, use background execution when appropriate and retain its returned `shell_id`.
- A tool timeout or a returned background handle means the command may still be running. It is neither success nor a test failure. Do not restart a command just because the tool returned before it finished.
- Use `get_output` on the same handle. For finite checks, choose a long wait within the tool's limit rather than rapid polling. With the current tool, waits can be up to 280,000 milliseconds and return early when the process exits; this is a per-call wait limit, not an overall runtime budget. Continue waiting while a check remains active unless the user cancels or an explicitly requested deadline is reached. If the user set a deadline, bound individual waits by the remaining time.
- For persistent servers or watchers, use short waits only to confirm startup, then verify readiness and the agreed observations. A server's startup message does not prove a test passed, and waiting for a server to exit is not a finite check.
- Inspect relevant output and any overflow files. Record the exit code, test counts or other required evidence, and whether the command actually terminated. Silent output is not proof of success, failure, or a hang.
- Report meaningful milestones, failures, blockers, and any explicitly configured deadline without flooding the conversation with repeated unchanged status. Keep monitoring while work is active; do not claim completion merely because commands were backgrounded.
- Respect cancellation immediately. If an explicitly requested deadline is reached, stop starting work and safely stop processes owned by this invocation using their tool handles. Never kill pre-existing or shared services. If stopping a process is unsafe or its termination cannot be confirmed, report that it may still be running and ask how to proceed.

## Handle failures honestly

In check-only mode, report a failed check without modifying the project or silently retrying it. Collect the results of already-running independent checks when safe, subject only to any explicitly requested runtime limit, but do not continue dependent work after a prerequisite fails.

If the user explicitly requested fixes, reproduce and diagnose the failure, make the smallest authorized change, and rerun the relevant checks followed by the full agreed verification scope. Respect the repair-round limit and any runtime limit explicitly set by the user. Keep the original failure visible; a later passing run does not erase a flaky result.

Stop and ask for help when blocked by authentication, permissions, missing infrastructure, required project configuration changes, or an action outside the agreed scope. State what was attempted, the evidence for the blocker, and the smallest decision needed. Never bypass an approval, a failing gate, or a security policy to continue.

## Preserve progress when needed

Use the task list and conversation for ordinary runs. If work may cross compaction or the user requests resumability, save a minimal checkpoint outside the repository under `${XDG_STATE_HOME:-$HOME/.local/state}/devin/goals/<run-id>.json`, using a unique filesystem-safe run ID and approved file tools. Verify directory access before writing.

Store only the objective summary, repository path and revision, awareness of uncommitted changes, scope, sanitized command descriptions, working directories, start time, optional user-requested deadline, attempt counts, results, active process handles, and the next action. Represent the absence of a deadline as null. Do not store credentials, sensitive output, uploaded documents, or raw logs. Never create repository-local `GOAL.md`, progress logs, uploads, or temporary-content directories for this workflow.

On resume, read the checkpoint, re-check the repository state, and confirm whether any recorded process still exists. Shell handles may not survive a session change; do not assume they are reusable or that missing handles imply success. Do not launch a duplicate until the previous command's status is understood. Preserve unlimited runtime across resumes when no deadline was requested. Preserve any explicitly requested deadline and retry counts unless the user explicitly changes them.

## Finish with evidence

Stop once the contract is satisfied; do not invent additional work. Report one overall status: **passed**, **failed**, **blocked**, **timed out**, or **cancelled**.

Include:

- Each agreed check, its working directory, observed exit status or active state, and the decisive evidence.
- Any checks not run, failed attempts, skipped tests, partial coverage, or limitations.
- Changes made, if fixes were authorized; otherwise make clear that this was check-only.
- Any process still running and the checkpoint location, if one was created.
- The smallest next action when the goal was not met.

Never claim a check passed without running it and observing its completion evidence. A persisted checkpoint or an active process is not a completed goal.

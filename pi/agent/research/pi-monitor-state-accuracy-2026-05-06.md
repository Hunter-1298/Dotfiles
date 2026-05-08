# State accuracy research — pi-monitor

**Goal:** identify why pi-monitor is not always accurate when reporting an agent
as `working`, `idle`, or `error`, and propose the cleanest path to a higher-
fidelity signal.

**Scope:** read-only analysis of pi-monitor (`src/pi_monitor/state.py`,
`notify.py`, `tui.py`) and the upstream truth source (pi-coding-agent's
`SessionManager`, `AgentSession`, extension lifecycle). No code changed.

---

## TL;DR

pi-monitor's classifier is a tail-of-JSONL state machine plus an `mtime ≥ N`
idle threshold. It is **structurally limited by what pi writes to disk**:

1. pi only flushes the session JSONL after the *first assistant message* of a
   session has been emitted (`SessionManager._persist`'s `hasAssistant` guard,
   `dist/core/session-manager.js:549`). A freshly-launched pi with a typed
   first prompt and a streaming first response has **zero bytes on disk**.
2. pi appends to the JSONL only at message boundaries (`message_end`). During
   long LLM streams, long bash runs, compaction, and auto-retry the file is
   **silent for tens of seconds**.
3. `stopReason: "error"` is written for *every* retryable transient
   (overload / 429 / 503 / network) before pi automatically retries
   (`agent-session.js:1921`). The error landing flips us to `ERROR` and fires
   a desktop notification even though the user has no action to take.

The fix path with the best accuracy-per-effort ratio is to **publish a
heartbeat file from inside pi via an extension** that subscribes to
`agent_start` / `agent_end` / `turn_start` / `tool_execution_*` /
`auto_retry_start` / `session_before_compact`, etc. pi-monitor reads that
file when present and falls back to the existing JSONL inference otherwise.

The runner-up improvement is small and worth doing regardless: collapse
short-lived `ERROR` blips during auto-retry, and call out two new states
(`WAITING` for permission/input prompts, `RETRYING` for transient API
errors) so notifications stop firing on transient hiccups.

---

## 1. How pi-monitor decides today

### 1.1 Pipeline (per pane, every 500 ms — `tui.py:65,645`)

```
list_panes() -> Pane[]
  └── tmux list-panes -aF '... pane_current_command'
        is_pi = (pane_current_command == "pi")
  └── pane_pid (the pane's shell pid)

StateResolver.resolve(refs):
  for each pi pane:
    pi_pid = walk /proc/<pane_pid>/task/.../children for comm="pi"
    pi_start = parse field 22 from /proc/<pi_pid>/stat + /proc/uptime
  group panes by cwd, sort start-ASC, claim a JSONL per pi:
    owned   = filename_ts ∈ [pi_start − 1s, next_pi_start − 1s)
    resumed = filename_ts < pi_start AND mtime ≥ pi_start
    else    = None
  reader.read(file)  -> tail 64KB, parse last message entry

infer_state(snapshot):
  last_error            -> ERROR
  last_role=="assistant"
    && stopReason=="error"               -> ERROR
    && stopReason∈{stop,length,aborted}
       && idle_for >= 1.0s               -> IDLE
       else                              -> WORKING
    && stopReason=="toolUse" / unknown   -> WORKING
  last_role∈{toolResult,user,bash,custom}-> WORKING
  None / no last_role                    -> UNKNOWN
```

Notifier (`notify.py:78`) fires `notify-send` only on transitions *into*
`{IDLE, ERROR}`, with a 2-second per-pane debounce.

### 1.2 What the model gets right

- Mid-conversation the file pattern matches the heuristic well: `user` →
  long `assistant` stream → `assistant{toolUse}` → tool runs (silent) →
  `toolResult` → next `assistant` ... → `assistant{stop}` → IDLE after 1 s.
- PR #9's filename-anchored claim window correctly handles cohabiting pi
  panes in a shared cwd.
- Tool errors (`toolResult.isError`) are deliberately **not** treated as
  agent errors — the agent will see the failure and react. This is correct.

---

## 2. What pi actually writes — the truth source

Verified against the installed
`@mariozechner/pi-coding-agent/dist/core/session-manager.js` and
`agent-session.js`.

### 2.1 Session file lifecycle

| Trigger                                                  | Effect on JSONL on disk                        |
| -------------------------------------------------------- | ---------------------------------------------- |
| `pi` starts (no session passed)                          | **No file created.** SessionManager has an in-memory buffer (`fileEntries`) only. |
| User types first prompt, agent_start fires               | UserMessage is appended to the in-memory buffer; **disk still empty** (`_persist` returns early because `hasAssistant === false`). |
| Assistant message_end                                    | The whole buffer (header + user + assistant) is flushed to disk in one `appendFileSync` loop, then `flushed = true`. |
| Subsequent message_end (assistant / user / toolResult)   | Each entry is appended in its own `appendFileSync` call. |
| `bashExecution` message during streaming                 | Queued in `_pendingBashMessages`, **flushed on agent_end**. |
| `/new` (in-place new session)                            | A *new* session file path is set, in-memory buffer reset, **no file written** until the new session's first assistant lands. |
| `/fork`, `/clone`, `forkFrom`                            | New file written **immediately** with the copied entries (calls `_rewriteFile` or direct `appendFileSync`). |
| Auto-compaction (`_runAutoCompaction`)                   | Calls a model in the background. Writes a single `compaction` entry on success. The JSONL's last entry remains the prior assistant (likely `stopReason: "stop"`) for the duration. |
| Retryable error                                          | Writes `assistant{stopReason: "error"}`, then sleeps `baseDelayMs * 2^(attempt-1)`, then retries. The retry produces a new assistant message that overwrites the disk-tail view, but only **after** the next stream completes. |

### 2.2 Implications for any disk-based observer

- **The file's existence is not equivalent to "agent has started"**.
- **The file's mtime is not a reliable proxy for activity** during long
  streams, long tools, compaction, or retry sleeps.
- **`stopReason: "error"` does not mean "the agent has failed"** — pi may be
  in the middle of an automatic recovery.

### 2.3 What pi *can* expose to extensions (and to us, indirectly)

Lifecycle events guaranteed in `docs/extensions.md` §Lifecycle Overview:

```
session_start
before_agent_start / agent_start / agent_end
turn_start / turn_end
message_start / message_update / message_end
tool_execution_start / tool_execution_update / tool_execution_end
tool_call (can block) / tool_result
before_provider_request / after_provider_response
auto_retry_start / auto_retry_end
session_before_compact / session_compact
session_before_switch / session_shutdown
```

Plus `ctx.isIdle()`, `ctx.hasPendingMessages()`, `ctx.waitForIdle()`. These
are the only sources that distinguish:

- "streaming a first assistant" vs. "no agent started"
- "auto-retrying" vs. "errored, user must intervene"
- "compacting" vs. "idle"
- "tool blocked on user permission" vs. "tool running"

None of those signals leak to disk through the JSONL.

---

## 3. Accuracy gaps (ranked by user impact)

| #  | Gap                                            | Real state          | What pi-monitor reports                                | Frequency             |
| -- | ---------------------------------------------- | ------------------- | ------------------------------------------------------ | --------------------- |
| G1 | First prompt before first assistant            | WORKING             | `UNKNOWN` (no file) or `IDLE` if an old file is bound  | every fresh pi launch |
| G2 | `/new` while old file still in cwd             | WORKING (new turn)  | `IDLE` (binds to old `assistant{stop}`)                | common                |
| G3 | Auto-retry on transient API error              | WORKING (retrying)  | `ERROR` + desktop notification fires for ~2–8 s         | common                |
| G4 | Auto-compaction in progress                    | WORKING (compacting)| `IDLE` (file silent, last entry is prior `stop`)       | common in long sessions |
| G5 | Tool blocked on user permission (`ui.confirm`) | NEEDS USER          | `WORKING` (silent — no notification)                    | extension-dependent   |
| G6 | Aborted (Esc) treated like normal stop         | needs_attention?    | `IDLE` after 1 s — indistinguishable from "done"        | common                |
| G7 | Cohabiting fresh pi vs. working pi             | one WORKING / one no-file | both correct **post-PR #9**                       | fixed                 |
| G8 | Pi running `!vim` / `!htop` (PTY-takeover)     | user-driven         | `NO_PI` — pane temporarily disappears from the tree     | rare                  |

### Reproductions

**G1** — verified live in `/proc`: pid `2624220` runs pi in
`~/micro1/Projects/govt/aca-contract-strategy-redesign`; the corresponding
`~/.pi/agent/sessions/--…--` directory does not exist. pi-monitor reports
`UNKNOWN`. If a user has just submitted a prompt there, the agent is
genuinely working.

**G3** — `_isRetryableError` (`agent-session.js:1921`) matches a wide
regex (`/overloaded|429|503|fetch failed|timeout|terminated|...`/i). Each
match writes `stopReason: "error"`, sleeps `baseDelayMs * 2^(attempt-1)`,
retries up to `maxRetries`. pi-monitor's `infer_state` flips to `ERROR`
on the first error landing and fires a critical-urgency notification.

**G4** — `_runAutoCompaction` runs another LLM call in the background.
The session's JSONL is not touched until compaction completes (a single
`compaction` entry is appended). The visible last entry remains the
prior assistant `stop`, so pi-monitor reports `IDLE` for the entire
compaction window (often 10–60 s on large contexts).

---

## 4. Signal scoring (highest accuracy per effort)

| Signal                                  | Solves            | Cost                                                                 | Verdict                                  |
| --------------------------------------- | ----------------- | -------------------------------------------------------------------- | ---------------------------------------- |
| **Pi extension publishes a heartbeat**  | G1, G2, G3, G4, G5 | One small TS extension (~50 LOC), one extra reader path in pi-monitor | **Best**. Authoritative, low-coupling.   |
| Inotify on `~/.pi/agent/sessions`       | latency only      | `watchdog` dep, ~20 LOC                                              | Worth doing as a perf/UX win regardless. |
| `/proc` process-tree introspection      | partial G1 (pi alive but no file → assume IDLE-vs-WORKING via child count) | small                                | Marginal. Doesn't solve G3/G4/G5.        |
| PTY scraping (`tmux capture-pane`)      | nothing reliably  | brittle                                                              | Reject.                                  |
| Pi RPC mode                             | all of them       | requires launching pi differently, breaks ad-hoc usage               | Reject for the default UX.               |
| Auto-retry awareness in pi-monitor (suppress brief ERROR) | G3 only | small (timer + transition state machine)                          | Cheap mitigation, no extension needed.   |

---

## 5. Recommended path forward

### 5.1 Tier 1 — high-fidelity signal via a pi extension

Ship `~/.pi/agent/extensions/pi-monitor-heartbeat.ts` (auto-discovered) that
writes a single small file per session, e.g.
`~/.pi/agent/sessions/--<cwd>--/.<session-id>.heartbeat.json`. Schema:

```jsonc
{
  "version": 1,
  "session_file": "/abs/path/to/<ts>_<uuid>.jsonl",
  "pid": 12345,
  "ts": 1735000000.123,                   // unix seconds, last update
  "phase": "agent_running" |               // agent_start..agent_end
           "tool_running" |                // tool_execution_start..end
           "awaiting_permission" |         // tool_call returned {block} OR ui.confirm pending
           "retrying" |                    // auto_retry_start..auto_retry_end
           "compacting" |                  // session_before_compact..session_compact
           "idle",                         // ctx.isIdle()
  "current_tool": "bash" | null,
  "retry_attempt": 0
}
```

The extension bridges every transition we care about:

| Pi event                                            | Extension action                                    |
| --------------------------------------------------- | --------------------------------------------------- |
| `session_start`                                     | write `phase: "idle"`                                |
| `agent_start`                                       | `phase: "agent_running"`                             |
| `agent_end`                                         | `phase: "idle"`                                      |
| `tool_execution_start`                              | `phase: "tool_running"`, `current_tool: <name>`      |
| `tool_execution_end`                                | restore prior phase                                  |
| `tool_call` interceptor (when `ctx.ui.confirm` ...) | `phase: "awaiting_permission"` (extension-level convention) |
| `auto_retry_start`                                  | `phase: "retrying"`, increment `retry_attempt`       |
| `auto_retry_end`                                    | restore prior phase                                  |
| `session_before_compact`                            | `phase: "compacting"`                                |
| `session_compact`                                   | restore prior phase                                  |
| `session_shutdown`                                  | delete heartbeat file                                |

pi-monitor's `state.py` adds a heartbeat reader that runs **before** the
JSONL inference. When the heartbeat file is present and fresh
(e.g. `ts > now − 5 s`), use it directly:

```
phase                  -> AgentState
"agent_running"        -> WORKING
"tool_running"         -> WORKING
"compacting"           -> WORKING        (with sub-label "compacting")
"retrying"             -> WORKING        (with sub-label "retry N/M")
"awaiting_permission"  -> WAITING        (NEW — needs-attention, not error)
"idle"                 -> IDLE           (no debounce needed; agent_end fired)
heartbeat stale or absent -> fall back to current JSONL inference
```

This eliminates G1, G2, G3, G4, G5 in a single, additive step. No change to
upstream pi required. The extension is opt-in: install it once, get
better monitoring forever; uninstall it, revert to the JSONL heuristic.

**Cost estimate:** ~50 LOC TS extension + ~80 LOC of Python in `state.py`
to read+gate the heartbeat. New `WAITING` enum value (`AgentState.WAITING`)
plus a glyph and a notification rule.

### 5.2 Tier 2 — fixes that need no extension

These are valuable on their own and ship faster.

- **Suppress brief `ERROR`s during auto-retry.** When we see
  `assistant{stopReason: error}` whose `errorMessage` matches the
  retryable-error regex (we can copy it from pi), defer the `ERROR`
  notification by `~10 s`. If a newer assistant message lands first, drop
  the notification. Solves G3 entirely from the outside.
- **Replace `mtime`-based polling with `inotify`** (`watchdog`). Pi appends
  whole lines; we'd get instant transitions and lower CPU at idle. Don't
  remove the 500 ms tick — keep it as a fallback for `/proc` walks.
- **Recognize the "I exist but have no file yet" case.** When a pi pane
  has a live `pi_pid` but `_claim_session_file` returns `None`, prefer
  reporting `STARTING` (a lighter-weight `WORKING`-equivalent without a
  notification) instead of `UNKNOWN`. A user typing into a brand-new pi
  is never genuinely "unknown" — they're either at the prompt
  (`STARTING`-as-IDLE-equivalent) or composing/streaming
  (`STARTING`-as-WORKING-equivalent). Either reading is less wrong than
  the current `❓`. Without a heartbeat we can't tell which one — pick
  one and document it (recommendation: `WORKING` on first claim attempt
  after pi_start, downgrade to `IDLE` if the file does not appear within
  ~30 s).

### 5.3 Tier 3 — nice-to-haves

- Add an explicit `RETRYING` state. With the heartbeat it's free; without
  it, derive it from the suppressed-`ERROR` window above.
- Add an explicit `WAITING` state distinct from `IDLE` (different glyph,
  different notification urgency). The current `IDLE` mixes "agent done,
  needs prompt" with "agent abandoned mid-task" (Esc).
- For the inspector panel, render `compacting`/`retrying`/`awaiting_permission`
  badges from the heartbeat — much more useful than the current
  "current_tool" line.

---

## 6. Concrete state-machine proposal

Six external states, in priority order:

| State    | Glyph | Notify? | Description                                                  |
| -------- | ----- | ------- | ------------------------------------------------------------ |
| ERROR    | ❌    | yes     | Persistent error: `stopReason:"error"` AND not retrying.     |
| WAITING  | 🟡    | yes     | Tool blocked on user (extension permission, ui.confirm).     |
| IDLE     | 🔴    | yes     | `agent_end` fired, no pending. Or `assistant{stop}` + 1 s.   |
| RETRYING | 🟠    | no      | `auto_retry_start` active, or recently-error tail w/ retryable msg. |
| WORKING  | 🟢    | no      | Anything else with a live signal (agent_running / tool_running / compacting / mid-stream). |
| UNKNOWN  | ❓    | no      | No live signal. Reserved for genuinely unobservable panes (no pid + no file). |

`STARTING` is not a separate state; "live pi, no file yet" maps to
`WORKING` (new pi launch is a working state by default, downgrade to
`IDLE` after a grace period if no file appears).

---

## 7. Recommended next steps

1. **Build the heartbeat extension** as a new sub-package under
   `pi-monitor` (e.g. `extensions/pi-monitor-heartbeat.ts`) and document
   `pi -e <path>` for trial use, then auto-install path under
   `~/.pi/agent/extensions/`.
2. **Wire pi-monitor to read the heartbeat first**, JSONL second. Add
   `AgentState.WAITING` and `AgentState.RETRYING`.
3. **Land Tier-2 fixes regardless** (retry suppression, inotify,
   STARTING-as-WORKING). They reduce false positives even for users who
   skip the extension.
4. **Validate** with three scripted scenarios — all currently misclassified:
   (a) fresh pi + first prompt; (b) pi inside auto-retry loop; (c) pi
   inside auto-compaction.

Each lands as its own PR per repo convention.

# cdao_powerbi orphan-route sweep — summary

**PR**: <https://github.com/c3-e/c3cdao-cra/pull/179>
**Branch**: `agent/hunter-poc-cdao-powerbi-sweep-20260507`
**Worktree**: `/home/hshayde/micro1/Projects/govt/cdao-powerbi-sweep`
**Base**: `hunter/poc` @ `a5b45a939` (post-PR #178 / `/dashboards` deletion)
**Status**: opened, not merged (per task spec — operator reviews + admin-merges).

## Files deleted by category

| Category                                                  | Count                                                             |
| --------------------------------------------------------- | ----------------------------------------------------------------- |
| Backend routers (`packages/powerbi/cdao_powerbi/routes/`) | 6                                                                 |
| Backend route + service tests (`packages/powerbi/tests/`) | 17 (15 listed + 2 phase2f tests that imported `routes.instances`) |
| Frontend hooks (`apps/aca/frontend/src/hooks/`)           | 3 (+ 1 test file)                                                 |
| Frontend component (`pbi-canvas/ThumbnailCapture.tsx`)    | 1 (+ 1 test file)                                                 |
| **Total deletions**                                       | **29 files (-9794 LOC)**                                          |

## Files modified

- `packages/powerbi/cdao_powerbi/plugin.py` — removed imports + configure() + module-list entries for the 6 deleted routers.
- `packages/powerbi/tests/test_plugin_user_authoring.py` — trimmed to surviving datasets-routing assertions.
- `apps/aca/backend/app/api/routes/dashboard_agent.py` — removed dead `instance_id` branch + the imports it required.
- `apps/aca/backend/tests/api/test_dashboard_agent_routes.py` — collapsed 11 → 6 tests (workspace-canvas-only paths).
- `apps/aca/frontend/src/components/pbi-canvas/DashboardCanvas.tsx` — dropped `instanceId` prop + the conditional `<ThumbnailCapture>` mount.
- `apps/aca/frontend/src/lib/powerbi-api.ts` — 27 helpers + their dedicated types deleted; 22 generated-SDK imports dropped.

**Total modifications**: 8 files, +67 LOC.
**Net delta across PR**: 37 files changed, +67 / -9855 (net **-9788 LOC**).

## Backend test count delta

| Suite                                                       | Before     | After      |
| ----------------------------------------------------------- | ---------- | ---------- |
| `packages/powerbi/tests`                                    | 491 passed | 283 passed |
| `apps/aca/backend/tests/api/test_dashboard_agent_routes.py` | 11 passed  | 6 passed   |

## Frontend tsc baseline-vs-final

| Stage                | Errors |
| -------------------- | ------ |
| Baseline (pre-edits) | 15     |
| Final (post-edits)   | 15     |

All 15 are pre-existing (`@cdao/ui` module-not-found + a few implicit-any `e` parameters). Zero new errors from this sweep.

## Snags + recoveries

- **Phase 1 collection failure**: `tests/test_phase2f_audit_logging.py` and `tests/test_phase2f_single_resolution.py` both import `cdao_powerbi.routes.instances`, breaking pytest collection after the routers were deleted. Spec only listed router-named test files but these phase2f tests exclusively exercise `routes/instances` entry points — same deletion bucket. Deleted both, collection clean.
- **Auto-format reverts during big block edits**: the lens edit tool flagged "ambiguous edit target" / "file modified since read" several times when deleting large multi-section blocks of `lib/powerbi-api.ts`. Recovered by breaking the deletion into smaller anchored chunks (one section at a time) and re-reading between blocks. No content corruption.
- **`@cdao/ui` and `@types/react` LSP noise**: the auto-installed lens lint complained about missing modules in the fresh worktree before `pnpm install` ran. Pre-existing across the codebase; ignored. Real `tsc --noEmit` was clean for all touched files.

## Decisions deferred

- **`hub.py` handler-level prune** — views, user-dashboards, categories, events, dashboards, refresh, chart-data are all dead but the router stays for live `/reports*` + `/embed-config/{slug}`. Out of this sweep.
- **`cdao_powerbi/services/{instance,layout,pin,thumbnail,template,wizard}_service.py`** — orphan post-deletion but kept conservatively (a follow-up sweep can prune them once we audit non-test consumers).
- **openapi.json + generated SDK regeneration** — codebase convention is to tolerate stale generated entries (per PR #161 body); deferred.

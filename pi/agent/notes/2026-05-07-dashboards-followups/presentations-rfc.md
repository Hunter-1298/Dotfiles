# RFC — Presentations / decks as a new agent surface

Status: design draft, decision-pending
Scope: dashboard agent (`/api/v1/dashboards/agent/plan`) extends or branches to also compose presentations / decks.

---

## 1. Problem

The dashboard agent today produces **dashboard widgets** — KPIs, notes, embedded Power BI reports, tables, images, markdown — laid out on a 12-col grid. Users have asked for the agent to also produce **presentations / decks** in the same "embedded" surface (i.e. inside the app, not as a downloaded `.pptx`). Decks are a different artifact: ordered slides, one focal idea per slide, a presenter / fullscreen mode. The current `Layout` schema can't express "ordered slides" — every widget sits in 2-D grid coordinates with no notion of slide boundary, transition, or reading order. We need to decide _what_ presentations mean here, and _where_ they live, before writing code.

---

## 2. Current scope (what we have today)

Grounding from the four reference files:

- **Widget vocabulary** is fixed at 8 types in `cdao_powerbi.schemas.layout`: `kpi`, `note`, `markdown`, `embed_report`, `embed_dashboard`, `chart`, `table`, `image`. The discriminated union is the wire-format authority; `Layout(extra="forbid")` means a new widget type must be added to this Pydantic union or it's rejected at the boundary.
- **Planner** (`agent_planner.py`) emits an _intermediate_ `_PlannedWidget` that drops ids/positions/workspace_id (server-stamped) and uses a named `size` enum (`small | medium | large | full`) mapped to a 12-col rectangle. Gemini 2.0 Flash. Always returns 200 — failure modes degrade to `source="passthrough"` with a typed `reason`.
- **Apply** never persists server-side. The route returns a `Layout`; the frontend `DashboardAgentComposer.handleApply` calls `toCanvasWidgets(plan.layout)` and forwards canvas-shape widgets to the parent's `onApply`, which routes through `handleWidgetsChange` → existing debounced layout PUT (`/powerbi/instances/{id}/layout` or `/powerbi/workspaces/{id}/layout`).
- **Composer UI** is a slide-down panel inside the floating dock. One textarea, one Compose button, one preview list (one row per widget), Apply / Discard. ~400 LOC; state machine `idle → thinking → done|failed`.
- **Two surfaces** share the route post-PR-#177: `/dashboards/instances/{id}/edit` (instance, permission-gated) and `/dashboard` (workspace canvas, own-grid auth). Adding a third surface or a slide artifact has to fit one of these auth models or introduce a new one.

---

## 3. What 'presentations / decks' could mean

| #   | Interpretation                                                                                                                       | Scope  | Reuse  | "Done" looks like                                                                                                                                                                                                        |
| --- | ------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A   | Server-side `.pptx` generation, returned as a downloadable file                                                                      | Medium | Low    | User types prompt → backend emits a `.pptx` via `python-pptx` → frontend offers a "Download deck" button. No in-app viewing.                                                                                             |
| B   | New widget type `slide_deck` on the existing canvas                                                                                  | Small  | High   | Add `SlideDeckWidget` to the layout union; planner picks it like any other widget; renders inline as a carousel inside the canvas grid.                                                                                  |
| C   | Separate `/presentations` route with its own canvas + schema                                                                         | Large  | Medium | New route, new `Deck` schema (ordered slides, slide-shaped not widget-shaped), new agent endpoint, fullscreen presenter mode. Parallel to `/dashboard`.                                                                  |
| D   | Markdown-driven slides via reveal.js inside a new `markdown_slides` widget                                                           | Small  | High   | One new widget type — renders `---`-separated markdown as an inline deck with prev/next + fullscreen toggle. Agent emits the markdown body.                                                                              |
| E   | **Hybrid**: a first-class `Deck` artifact (own slide schema) rendered on the canvas as a tile that expands to a fullscreen presenter | Medium | High   | New slide schema. Canvas gets a `deck` tile widget that's a thumbnail + "Present" CTA. Click → fullscreen viewer. Agent's existing intermediate JSON contract is extended with a new widget type that _contains_ slides. |

**Trade-off summary:**

- **A** ships fast but breaks the "embedded" constraint the user gave. Files, not in-product surfaces.
- **B** is the smallest delta but cramps the slide UX into a 12-col grid cell — slides need fullscreen reading.
- **C** is the most "correct" architecturally and the most expensive — duplicates dock + planner + apply + auth.
- **D** is cheapest and ships in days, but caps the surface at markdown — no embedded reports per slide, no images per slide as first-class fields.
- **E** captures the slide-native UX (presenter mode) without forking the agent infrastructure. The deck _is_ a widget on the canvas, but rendering treats it specially.

---

## 4. Recommended approach: **Option E — Deck artifact as a canvas tile + fullscreen presenter**

Pick E. Justification:

- The user said "in the embedded space" — rules out A. They want decks alongside dashboards, not separate downloads.
- A deck is conceptually one artifact (a series of slides), not 12 atomic widgets — pure B (one widget per slide) loses the "series" abstraction and can't drive a presenter mode.
- C duplicates infrastructure that already works (dock, planner, apply pipeline, auth). Worth doing only if the deck UX has needs the dashboard surface can't satisfy _at all_ — which we won't know until E is in users' hands.
- D is a fine fallback if E proves too expensive — markdown decks are a real product in the wild (reveal.js, Slidev). We can ship D first and graduate to E if usage justifies it.
- E reuses the planner's intermediate JSON pattern: add a `deck` planner widget type whose `slides` field is an ordered list. The route, auth, apply pipeline, and dock all keep working unchanged.

**Risks:**

- Slide schema design lock-in. Once a `slide_deck` shape lands in `cdao_powerbi.schemas.layout`, it's a wire-format contract. Get the slide vocabulary right _before_ shipping (text, image, embed_report-per-slide, speaker_notes, transition?).
- Fullscreen presenter is real UX work — keyboard nav, presenter notes, fullscreen API, escape handling, no-flicker transitions. Not a weekend.
- The planner's current `_GENERAL_SIZE_MAP` rectangles don't apply to slides — slides are full-canvas, not 12-col. Need a separate pre-projection branch in `_project_widget` for the deck type.
- Power BI embed-per-slide is doable but adds an axis: the planner has to pick which report goes on which slide, and the embed widget is currently grid-positioned not slide-positioned. May need to constrain embeds to one-per-slide in v1.
- Export-to-`.pptx` (option A's value prop) is **deferred** in this approach. Some users want offline-shareable artifacts — tag this as a follow-up, don't bundle.

---

## 5. Phasing

Each milestone is independently shippable; later milestones don't change the wire format set in earlier ones (additive only).

**M1 — Slide schema + minimal `slide_deck` widget (no agent integration)**

- Add `SlideDeckWidget` to `cdao_powerbi.schemas.layout` union: `slides: list[Slide]`, where `Slide` has `title`, `body` (markdown), optional `image_url`, optional `embed_report_id`, optional `speaker_notes`. Cap slides at 30 per deck.
- Frontend: `<SlideDeckTile>` that renders as a canvas widget (thumbnail of slide 1 + "Present" CTA), and `<SlideDeckPresenter>` as a fullscreen overlay (keyboard nav, fullscreen API, esc to close).
- Manual creation only — drag the new widget type onto the canvas, edit slides via a drawer.
- Verify: type checks pass, layout PUT round-trips a deck, presenter mode renders on Cmd+P / "Present" click.

**M2 — Planner support: agent can compose a deck**

- Extend `_PlannedWidget` with a `slides` array (matching M1's `Slide` shape minus ids).
- Update `_SYSTEM_PROMPT` with a new widget type entry: when to use `slide_deck` vs `markdown` vs individual widgets. Add a rule capping slides at ~10 in agent-generated decks.
- Update `_project_widget` to handle the deck branch — slides project to the slide schema, embed_report ids on slides validate against the workspace's available reports the same way embed widgets do.
- Tests: new planner unit tests covering deck output, embed-report-on-slide projection, slide-count cap.
- Verify: `pnpm vitest` + `pytest` green; manual test of "Build me a 5-slide pitch on Project X" producing a usable deck.

**M3 — Polish + speaker notes + transitions**

- Speaker notes pane in presenter mode (split-screen).
- Slide transitions (fade / cut). Simple, no pyrotechnics.
- Per-slide image upload via existing blob store.
- Verify: usability test against 3 real prompts; presenter mode runnable end-to-end.

**M4 (deferred — separate decision)** — Export to `.pptx`

- `python-pptx` server-side, hand-off endpoint `POST /dashboards/decks/{deck_id}/export`.
- Deferred because (a) the in-app embedded path is the user's stated requirement; (b) `.pptx` introduces a separate auth/distribution problem (SharePoint? email? signed URL?).

---

## 6. Open questions

Things to confirm before M1 starts:

1. **Fullscreen vs modal:** is "Present" a true browser-fullscreen request (the Fullscreen API), or a maximized in-app modal? Fullscreen breaks if the user has multi-monitor presenter setups.
2. **Slide vocabulary:** are `title + markdown body + optional image + optional embed_report` enough for v1, or do users need bullet builds, multi-column slides, speaker timer, etc.? Each addition expands the planner's prompt and the schema surface.
3. **Embed-per-slide:** should a slide be allowed to embed a Power BI report _or_ a Power BI dashboard _or_ both? In v1 I'd cap at one embed per slide. Confirm.
4. **Deck-on-dashboard vs deck-as-route:** is the canvas tile the only way to get to a deck, or do we also want `/decks` as a top-level list view (analogous to the now-deleted `/dashboards` catalog)? The user just removed `/dashboards`; doing the same to `/decks` later is annoying.
5. **Presenter-mode auth:** when a user "presents", does the embedded Power BI in slide 4 still need a fresh embed token? (Likely yes — the existing `usePowerBiEmbedConfig` flow should work, but presenter mode shouldn't refresh the token mid-presentation if it ages out.)
6. **Authoring after agent generation:** post-Apply, can the user manually edit individual slides? The dashboard agent today returns a Layout that fully replaces the canvas. Decks should arguably be patchable slide-by-slide — but that's M3, not M1.
7. **Persistence model:** decks live in `Layout.widgets` as a single `slide_deck` widget. Is that sufficient, or should `Deck` be its own row (so versioning, sharing, and permissions are deck-shaped, not canvas-shaped)? For v1 inline-in-Layout is simplest; raise this if multi-canvas or shareable decks become a requirement.
8. **`.pptx` export priority:** is M4 actually deferred indefinitely, or is "export to PowerPoint" a known asks? If government users will need decks emailable to stakeholders without app access, M4 graduates from M4 to M2.5.

---

## Decision needed

- Confirm option **E** (Deck artifact + presenter) over A/B/C/D, or pick a different one.
- Answer questions 1–4 at minimum before M1 design lock.
- Confirm M4 deferral — or pull it forward if `.pptx` is a hard requirement.

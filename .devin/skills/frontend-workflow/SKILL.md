---
name: frontend-workflow
description: "UI workflow covering design research, skill routing and the quality bar. Use when building or changing UI: product screens and UX flows, landing or marketing pages, product illustrations and demos, or motion."
---

# Frontend workflow

Mobbin supplies ideas and direction; `design-taste-frontend` turns them into working UI for this application; `stageshow` supplies product illustrations and staged walkthroughs. Scale every step to the size of the UI change.

`design-taste-frontend`, `awesome-design-md`, `stageshow` and `design-to-motion` are type-only skills: to use one, read `~/.agents/skills/<name>/SKILL.md` and follow it, resolving its relative paths against that folder.

1. Read the brief, the existing UI and the project's design contract (tokens, components, brand).
2. For new screens or meaningful UX changes, study a few relevant Mobbin screens and flows for feature ideas, interactions and visual direction, and link the useful ones. Reuse earlier research for small follow-ups; minor fixes skip research. Keep Mobbin queries non-sensitive and follow its tool and attribution rules.
3. Route by the kind of work:
   - **Product UI**: for new screens and redesigns, read `design-taste-frontend`, plus `awesome-design-md` when a reference design system helps. Small changes follow the repo's existing patterns.
   - **Landing pages, marketing sites and other conversion pages**: invoke `landing-page-design` for intake, structure, copy, SEO and its visual system. In-app product UI stays on the product route.
   - **Product illustrations and demos** (faux product UI, still product shots, hero and feature-card art, bento mockups, cursor walkthroughs): read `stageshow`. Start from its closest bundled example and kit; plan one clear story and payoff, a readable still or reduced-motion state and a compact mobile composition; keep simulated content identifiable as illustrative. Project rules govern its dependencies, browser recording, exports and verification.
   - **Motion**: read `design-to-motion` to animate a supplied design, Figma frame, screenshot or mockup into a showcase loop or MP4/GIF export, and for other landing-page visuals and logo rows. Product-UI scenes come from `stageshow`; in-product interactions (hovers, menus, toasts) use normal implementation patterns.
4. Adapt every pattern to this app's users, workflows, brand, tokens and components. The project's own tokens and components win over any skill's defaults.
5. Pick a coherent direction, state it in a sentence, and build it: functional, accessible and responsive, with the states it needs.
6. Avoid unnecessary secondary labels and descriptions. Let the layout do the explaining. On landing pages, `landing-page-design`'s page structure (including its benefit-statement section) governs.
7. Verify with a browser E2E run (Playwright or your harness's browser), keeping mobile and desktop screenshots as the repeatable artifact. Check the result against `web-design-guidelines`, run the project's checks, then iterate with the user on the working result.

When delegating UI work to another agent, pass along this skill and the references you chose.

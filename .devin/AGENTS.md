# Build-first Working Style

Prioritize building and shipping the requested outcome. Keep work focused and proportional.

- Be concise: brief progress updates and a few bullets at handoff. Avoid long explanations unless requested.
- Make the smallest coherent change that delivers the requested behavior. Investigate only the context needed; avoid exhaustive exploration or prolonged planning for straightforward work.
- Do not perform unrelated refactoring, cleanup, architectural redesigns, dependency upgrades, or documentation work.
- Do not initiate security audits, vulnerability hunts, compliance reviews, or optional hardening unless explicitly requested. Preserve existing security controls and secure implementation practices; fix concrete security defects introduced by the current change without expanding into an audit.
- During routine building, use only lightweight verification of changed behavior and mandatory project checks. Do not automatically start broad regression suites, E2E campaigns, coverage drives, or lengthy test-writing efforts. Reserve broad testing for explicit testing requests or major deployment/release work. Preserve required CI and release gates.
- Keep skill workflows within the assigned scope. Generic skill recommendations must not automatically impose coverage targets, comprehensive testing, security reviews, or unrelated improvements. Preserve the UI design workflow below, applying its checks proportionally to the changed UI.
- Fix regressions caused by the current change. Report unrelated failures briefly without expanding scope. State what was and was not verified; never imply unrun checks passed.
- Stop when the requested behavior is implemented and proportionate verification is complete. Building and shipping priority does not authorize deployment, publishing, destructive actions, or bypassing required approvals.

# Frontend Design

**Mobbin supplies ideas and direction; Taste and frontend-design skills turn them into working UI for the current application. Stageshow supplies product illustrations and staged walkthroughs.**

- Understand the brief, existing UI, and design contract. For new screens or meaningful UX changes, inspect a few relevant Mobbin screens/flows for feature ideas, interactions, and visual direction. Briefly link useful references; reuse research for small follow-ups.
- Invoke `design-taste-frontend`, `frontend-design` when available, and relevant frontend implementation skills—or read their `SKILL.md` files. Use `awesome-design-md` only when helpful. Adapt patterns to the app's users, workflows, brand, tokens, and components rather than copying another product or imposing generic skill aesthetics.
- Landing pages, marketing sites, and other conversion pages: invoke `landing-page-design` for intake, page structure, copy, SEO, and its visual system. A project's own tokens and components win over the skill's defaults. Do not apply it to in-app product UI.
- Product illustrations and demos: invoke `stageshow` from `benjitaylor/skills` for faux product UI, still product shots, hero/feature-card illustrations, UI mockups in bento grids, and animated cursor walkthroughs. Start from the closest bundled example and kit, adapted to the product's brand, tokens and components. Plan one clear story and payoff, a readable still/reduced-motion state, and a compact mobile composition. Keep simulated content identifiable as illustrative. Project rules govern dependencies, browser recording, exports and verification.
- Motion: invoke `design-to-motion` when asked to animate a supplied design, Figma frame, screenshot, or mockup into a showcase loop or MP4/GIF export, and for other landing-page visuals and logo rows. Use `stageshow` to author product-UI scenes. These showcase workflows do not replace implementation patterns for in-product interactions such as hovers, menus and toasts.
- Choose a coherent direction, explain it briefly, and execute. Make routine design decisions independently; ask only about consequential ambiguity or scope changes. Suggest extra features rather than silently adding them, and iterate with the user on the working result.
- Build functional, accessible, responsive UI with appropriate states. Apply `web-design-guidelines`, run proportional project checks, and inspect mobile/desktop when tooling allows. Briefly report what was and wasn't verified.
- Cut taglines, helper text and secondary labels from product UI. If a screen needs them to
  make sense, fix the layout. On landing pages, `landing-page-design`'s page structure
  (including its benefit-statement section) governs. Make the best decision that will elevate all
  three: the user experience (UX), developer experience (DX), and agent
  experience (AX) always
- Keep Mobbin queries non-sensitive and follow its tool and attribution requirements. If research or a skill is unavailable, disclose it and use existing project guidance where practical instead of stalling.

Keep this workflow lightweight and limited to UI work; skip fresh research for minor fixes and unrelated tasks. Pass this policy and selected references to delegated UI agents.

# Disk Hygiene

WSL's virtual disk lives on C:, which has limited free space. When C: fills up, WSL crashes for every agent.

- Before a large Docker build, image pull or dataset/model download, check C: with `df -h /mnt/c`. If less than 30GB is free, clean up first or tell the user.
- Locally built Docker images: reuse one tag (e.g. `app:local`). Don't create a new tag per commit or experiment. Run `docker rmi` on superseded tags, and `docker builder prune -f --filter until=24h` after heavy build sessions.
- Put scratch clones, build contexts, worktrees and test output in `$TMPDIR` (`~/.cache/tmp`). Reuse a fixed directory instead of a new `mktemp` copy on every run. When the task is done, delete them (`git worktree remove`, `rm -rf`).
- Remove stopped containers and volumes from throwaway runs. Never leave duplicate multi-GB artifacts (zips, extracted packages, venvs) behind.

# GitHub Accounts

- Tradewinds repos (`alex-micro1/tradewinds-*`): use the `hunter-micro1` gh account for all git and `gh` operations. Do not switch the active gh account or edit git/gh config; pass the token per command and bypass the plaintext `store` helper:
  - `GH_TOKEN="$(gh auth token --user hunter-micro1)" git -c credential.helper= -c 'credential.helper=!gh auth git-credential' fetch origin`
  - `GH_TOKEN="$(gh auth token --user hunter-micro1)" gh pr create ...`

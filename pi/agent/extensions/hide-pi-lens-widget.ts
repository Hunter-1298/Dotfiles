import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// hide-pi-lens-widget
//
// Keeps pi-lens running (diagnostics, blocking writes, context injection
// all still work) but hides the diagnostics widget below the editor.
//
// pi-lens has no flag/config for this — it just defaults `lensWidgetVisible`
// to true. We deferred-unmount its widget by key after every session_start
// so we don't depend on extension load order: pi-lens (installed via
// `pi install`, loaded from configured paths) runs its session_start
// handler AFTER global extensions like this one. Scheduling the unmount
// on a microtask via setTimeout(0) lets pi-lens mount first, then we
// immediately remove it.
//
// Per-session re-enable: run `/lens-widget-toggle` once to show it again.

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		setTimeout(() => {
			try {
				ctx.ui?.setWidget?.("pi-lens", undefined);
			} catch {
				// pi-lens not loaded or API changed — silently ignore.
			}
		}, 0);
	});
}

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// auto-worktree
//
// When pi launches with `--worktree` inside a git repo on a named
// branch, create a fresh worktree at
// <repo_parent>/<repo>-<branch>-<ts> on a new branch
// agent/<branch>-<ts>, then re-exec pi inside it (without `--worktree`,
// so the child doesn't loop). The parent pi blocks on the child via
// spawnSync so the user sees a single continuous process. Without
// `--worktree`, the extension is a no-op and pi runs in place.
//
// `-w` SHORT FORM: pi v0.76+ rejects unknown single-dash flags in its
// CLI parser before any extension factory runs, so `pi -w` produces
// `Error: Unknown option: -w` and never reaches this extension. We pair
// this extension with a tiny `pi()` zsh function (see Dotfiles
// zsh/zshrc) that translates `pi -w` -> `pi --worktree` so the short
// form keeps working for interactive shells. Non-zsh shells / scripts
// should use `--worktree` directly.
//
// Per-project opt-in: a repo can opt into auto-worktree without passing
// `-w` every time by setting `{ "autoWorktree": true }` in
// <repo>/.pi/settings.json. We resolve the file relative to the git
// toplevel so it works from any subdirectory. The CLI flag and the
// setting are equivalent triggers; the rest of decide() / safeCleanup()
// behave identically either way. The recursion guard still prevents the
// re-exec child from looping when the worktree also contains the
// committed settings file.
//
// We also handle the "new tab inside an existing agent worktree" case:
// terminal emulators (e.g. Ghostty) inherit cwd for new tabs by default,
// so opening a tab from a window already running pi inside
// <repo>-<branch>-<ts> would otherwise land another pi in the SAME
// worktree. When we detect that situation (linked worktree AND branch is
// agent/*) we look up the base branch we recorded at creation time and
// spin up a fresh worktree next to the main repo instead. Worktrees
// created before the piBase config key existed get a regex fallback:
// parse the timestamp suffix off `agent/<base>-YYYYMMDD-HHMMSS` and use
// the captured `<base>` if (and only if) it resolves to a real ref.
//
// Skip (pi runs normally) when:
//   - `--worktree` was not passed on the command line and no project
//     opt-in via .pi/settings.json
//   - PI_WORKTREE_ALREADY=1 is set (we are the re-exec child)
//   - not inside a git repo
//   - HEAD is detached (no named branch)
//   - already inside a linked worktree whose branch is not agent/*, or is
//     agent/* but has no recorded base branch AND the parsed candidate
//     doesn't resolve (e.g. nested base like feature/foo whose slashes
//     were encoded to dashes — we can't round-trip those unambiguously)
//
// On child exit we attempt safe cleanup: remove the worktree and delete
// the local agent branch only when the worktree has no uncommitted/
// untracked changes, has zero commits past the base, AND has no remote
// counterpart at origin/<agentBranch>. A remote counterpart means the
// branch may be the source of an open PR — deleting it would close the PR
// on GitHub — so we keep both worktree and branch and let the user clean
// up by hand. Remote branches are never deleted by this extension.
//
// The factory returns a Promise that never resolves on the worktree path:
// process.exit(child.status) ends the parent before pi proceeds with
// session_start, so AGENTS.md / MCP / system-prompt cwd are loaded fresh
// in the child against the worktree.

const RECURSION_GUARD = "PI_WORKTREE_ALREADY";
const PI_BASE_CONFIG_KEY = "piBase";
// We still match `-w` here for two reasons: backward compatibility with
// any caller that bypassed pi's argv parser (e.g. invoking the factory
// directly from a test), and the recursion-guard child path where
// we set argv ourselves. The interactive `pi -w` form is handled by
// the shell-function wrapper that translates -w to --worktree before
// pi sees it.
const WORKTREE_FLAGS = new Set(["-w", "--worktree"]);

// Returns the argv with any -w / --worktree occurrences removed, or null
// if the flag was not present. Exported for tests.
export function stripWorktreeFlag(argv: readonly string[]): string[] | null {
	let found = false;
	const out: string[] = [];
	for (const a of argv) {
		if (WORKTREE_FLAGS.has(a)) {
			found = true;
			continue;
		}
		out.push(a);
	}
	return found ? out : null;
}

function baseConfigKey(agentBranch: string): string {
	return `branch.${agentBranch}.${PI_BASE_CONFIG_KEY}`;
}

interface ExecResult {
	stdout: string;
	stderr: string;
	code: number;
}

interface Decision {
	action: "skip" | "worktree";
	reason?: string;
	worktreeDir?: string;
	agentBranch?: string;
	baseBranch?: string;
}

interface DecisionDeps {
	env: NodeJS.ProcessEnv;
	exec: (cmd: string, args: string[]) => Promise<ExecResult>;
	statIsFile: (path: string) => boolean;
	now: () => Date;
}

export async function decide(deps: DecisionDeps): Promise<Decision> {
	if (deps.env[RECURSION_GUARD]) {
		return { action: "skip", reason: "recursion guard set" };
	}

	const gitDir = await deps.exec("git", ["rev-parse", "--git-dir"]);
	if (gitDir.code !== 0) {
		return { action: "skip", reason: "not a git repo" };
	}

	const top = await deps.exec("git", ["rev-parse", "--show-toplevel"]);
	if (top.code !== 0 || !top.stdout.trim()) {
		return { action: "skip", reason: "no git toplevel" };
	}
	const toplevel = top.stdout.trim();

	const branchResult = await deps.exec("git", [
		"symbolic-ref",
		"--short",
		"HEAD",
	]);
	if (branchResult.code !== 0 || !branchResult.stdout.trim()) {
		return { action: "skip", reason: "detached HEAD" };
	}
	const branch = branchResult.stdout.trim();

	const dotGit = join(toplevel, ".git");
	const inLinkedWorktree = deps.statIsFile(dotGit);

	let baseBranch: string | undefined;
	let mainRepoToplevel: string;

	if (inLinkedWorktree) {
		// Tabs / panes that inherit cwd from a window already running pi will
		// land here. Only treat this as a re-launch when the worktree is one we
		// created (branch is agent/*) AND we can recover the base branch — first
		// from the marker we wrote at creation, then by parsing the agent
		// branch name itself. Anything else is a user-managed worktree and we
		// leave it alone.
		if (!branch.startsWith("agent/")) {
			return { action: "skip", reason: "already in a linked worktree" };
		}

		const piBase = await deps.exec("git", [
			"config",
			"--get",
			baseConfigKey(branch),
		]);
		if (piBase.code === 0 && piBase.stdout.trim()) {
			baseBranch = piBase.stdout.trim();
		} else {
			// Fallback for agent worktrees created before the piBase config key
			// was introduced (Dotfiles f200595, 2026-05-11). Branch names we
			// generate look like `agent/<safeBranch>-YYYYMMDD-HHMMSS`, so peel
			// the timestamp off the suffix and use the captured prefix — but
			// only if it resolves to a real ref. `safeBranch` replaces `/` with
			// `-`, so nested bases like `feature/foo` round-trip to `feature-foo`
			// which won't be a ref; those drop through to the skip below, which
			// matches the previous behavior for unrecoverable worktrees.
			const parsed = branch.match(/^agent\/(.+)-\d{8}-\d{6}$/);
			const candidate = parsed?.[1];
			if (candidate) {
				const verify = await deps.exec("git", [
					"rev-parse",
					"--verify",
					"--quiet",
					`refs/heads/${candidate}`,
				]);
				if (verify.code === 0) {
					baseBranch = candidate;
				}
			}
			if (baseBranch === undefined) {
				return {
					action: "skip",
					reason: "in agent worktree but no recorded base branch",
				};
			}
		}

		const commonDir = await deps.exec("git", [
			"rev-parse",
			"--path-format=absolute",
			"--git-common-dir",
		]);
		if (commonDir.code !== 0 || !commonDir.stdout.trim()) {
			return { action: "skip", reason: "could not resolve main repo path" };
		}
		mainRepoToplevel = dirname(commonDir.stdout.trim());
	} else {
		baseBranch = branch;
		mainRepoToplevel = toplevel;
	}

	const safeBranch = baseBranch.replace(/\//g, "-");
	const d = deps.now();
	const ts =
		`${d.getFullYear()}` +
		`${String(d.getMonth() + 1).padStart(2, "0")}` +
		`${String(d.getDate()).padStart(2, "0")}` +
		"-" +
		`${String(d.getHours()).padStart(2, "0")}` +
		`${String(d.getMinutes()).padStart(2, "0")}` +
		`${String(d.getSeconds()).padStart(2, "0")}`;
	const repoName = basename(mainRepoToplevel);
	const worktreeDir = join(
		dirname(mainRepoToplevel),
		`${repoName}-${safeBranch}-${ts}`,
	);
	const agentBranch = `agent/${safeBranch}-${ts}`;

	return {
		action: "worktree",
		worktreeDir,
		agentBranch,
		baseBranch,
	};
}

function git(
	args: string[],
	cwd?: string,
): { stdout: string; stderr: string; code: number } {
	const r = spawnSync("git", args, { cwd, encoding: "utf8" });
	return {
		stdout: r.stdout ?? "",
		stderr: r.stderr ?? "",
		code: r.status ?? 1,
	};
}

// Decide whether a branch's commits are safe to discard. A branch is safe
// only when there are zero commits past the base AND no remote counterpart
// at origin/<branch>. The remote check is critical: if a remote branch
// exists it may be the source of an open PR, and deleting the local copy
// (or worse, the remote) would close the PR on GitHub. Pure-ish so it can
// be reused by pi-worktree-gc against dir-less branches by passing a cwd
// that has an origin remote.
export function checkBranchSafe(
	agentBranch: string,
	baseBranch: string,
	cwd?: string,
): { safe: true } | { safe: false; reason: string } {
	const remoteRef = `refs/remotes/origin/${agentBranch}`;
	const remoteExists = git(
		["rev-parse", "--verify", "--quiet", remoteRef],
		cwd,
	);
	if (remoteExists.code === 0) {
		return {
			safe: false,
			reason: `remote branch origin/${agentBranch} exists (likely PR source)`,
		};
	}

	const ahead = git(
		["rev-list", "--count", `${baseBranch}..${agentBranch}`],
		cwd,
	);
	if (ahead.code !== 0) {
		return {
			safe: false,
			reason: `git rev-list failed: ${ahead.stderr.trim()}`,
		};
	}
	const aheadCount = ahead.stdout.trim();
	if (aheadCount === "0") {
		return { safe: true };
	}
	return {
		safe: false,
		reason: `${aheadCount} unpushed commit(s) on ${agentBranch}`,
	};
}

export function safeCleanup(
	worktreeDir: string,
	agentBranch: string,
	baseBranch: string,
): { removed: boolean; reason?: string } {
	if (!existsSync(worktreeDir)) {
		return { removed: false, reason: "worktree directory missing" };
	}

	const status = git(["status", "--porcelain"], worktreeDir);
	if (status.code !== 0) {
		return {
			removed: false,
			reason: `git status failed: ${status.stderr.trim()}`,
		};
	}
	if (status.stdout.trim()) {
		return { removed: false, reason: "uncommitted or untracked changes" };
	}

	const safety = checkBranchSafe(agentBranch, baseBranch, worktreeDir);
	if (!safety.safe) {
		return { removed: false, reason: safety.reason };
	}

	const rm = git(["worktree", "remove", worktreeDir]);
	if (rm.code !== 0) {
		return {
			removed: false,
			reason: `git worktree remove failed: ${rm.stderr.trim()}`,
		};
	}

	const del = git(["branch", "-D", agentBranch]);
	if (del.code !== 0) {
		return {
			removed: true,
			reason: `worktree removed but branch delete failed: ${del.stderr.trim()}`,
		};
	}

	// `git branch -D` does not clean up `branch.<name>.*` config; drop the
	// piBase marker so stale keys don't accumulate. Best-effort; ignore
	// failures (exit 5 = key already absent).
	git(["config", "--unset", baseConfigKey(agentBranch)]);

	return { removed: true };
}

// Read <git-toplevel>/.pi/settings.json and return true iff it contains
// `autoWorktree: true`. Any failure (no git, missing file, malformed
// JSON, wrong type) yields false — the extension stays a no-op. The
// recursion guard short-circuits so the re-exec child does not re-trigger
// on the same setting.
export async function checkProjectOptIn(
	deps: Pick<DecisionDeps, "env" | "exec"> & {
		readFile: (path: string) => string;
	},
): Promise<boolean> {
	if (deps.env[RECURSION_GUARD]) return false;

	const top = await deps.exec("git", ["rev-parse", "--show-toplevel"]);
	if (top.code !== 0 || !top.stdout.trim()) return false;

	const settingsPath = join(top.stdout.trim(), ".pi", "settings.json");
	let raw: string;
	try {
		raw = deps.readFile(settingsPath);
	} catch {
		return false;
	}
	let parsed: unknown;
	try {
		parsed = JSON.parse(raw);
	} catch {
		return false;
	}
	return (
		typeof parsed === "object" &&
		parsed !== null &&
		(parsed as { autoWorktree?: unknown }).autoWorktree === true
	);
}

export default async function (pi: ExtensionAPI) {
	// Register `--worktree` so pi's argv parser doesn't reject it.
	// Without this, `pi --worktree` raises 'Unknown option' AFTER all
	// extension factories run (in applyExtensionFlagValues). The flag
	// value itself isn't readable until that phase, but we don't need
	// it — we inspect process.argv directly below, which works because
	// the factory runs synchronously enough that argv is intact.
	pi.registerFlag("worktree", {
		type: "boolean",
		default: false,
		description:
			"Create a fresh agent/<base>-<ts> worktree and re-exec pi inside it",
	});

	const rawArgs = process.argv.slice(2);
	let childArgs = stripWorktreeFlag(rawArgs);
	if (childArgs === null) {
		// No CLI opt-in. Check whether the project opted in via
		// .pi/settings.json — if so, behave as if -w had been passed.
		const projectOptedIn = await checkProjectOptIn({
			env: process.env,
			exec: async (cmd, args) => {
				const r = await pi.exec(cmd, args);
				return {
					stdout: r.stdout ?? "",
					stderr: r.stderr ?? "",
					code: r.code ?? 1,
				};
			},
			readFile: (p) => readFileSync(p, "utf8"),
		});
		if (!projectOptedIn) return;
		childArgs = rawArgs;
	}

	const decision = await decide({
		env: process.env,
		exec: async (cmd, args) => {
			const r = await pi.exec(cmd, args);
			return {
				stdout: r.stdout ?? "",
				stderr: r.stderr ?? "",
				code: r.code ?? 1,
			};
		},
		statIsFile: (p) => existsSync(p) && statSync(p).isFile(),
		now: () => new Date(),
	});

	if (decision.action === "skip") return;

	const { worktreeDir, agentBranch, baseBranch } =
		decision as Required<Decision>;

	process.stderr.write(
		`auto-worktree: creating ${worktreeDir} on ${agentBranch} (base ${baseBranch})\n`,
	);

	const created = await pi.exec("git", [
		"worktree",
		"add",
		"-b",
		agentBranch,
		worktreeDir,
		baseBranch,
	]);
	if (created.code !== 0) {
		process.stderr.write(
			`auto-worktree: worktree creation failed (${created.stderr.trim()}); continuing in current directory\n`,
		);
		return;
	}

	// Record the base branch on the agent branch's config so a pi launched
	// in a new terminal tab that inherits this worktree's cwd can recover it
	// and create its own fresh worktree instead of piling on top.
	const recordBase = await pi.exec("git", [
		"-C",
		worktreeDir,
		"config",
		baseConfigKey(agentBranch),
		baseBranch,
	]);
	if (recordBase.code !== 0) {
		process.stderr.write(
			`auto-worktree: failed to record base branch (${recordBase.stderr.trim()}); new tabs in ${worktreeDir} will skip worktree creation\n`,
		);
	}

	const child = spawnSync("pi", childArgs, {
		cwd: worktreeDir,
		stdio: "inherit",
		env: { ...process.env, [RECURSION_GUARD]: "1" },
	});

	const result = safeCleanup(worktreeDir, agentBranch, baseBranch);
	if (result.removed && !result.reason) {
		process.stderr.write(`auto-worktree: removed ${worktreeDir}\n`);
	} else if (result.removed && result.reason) {
		process.stderr.write(
			`auto-worktree: removed ${worktreeDir} (${result.reason})\n`,
		);
	} else {
		process.stderr.write(
			`auto-worktree: kept ${worktreeDir} (${result.reason})\n`,
		);
	}

	process.exit(child.status ?? 0);
}

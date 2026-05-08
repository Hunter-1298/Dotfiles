import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// auto-worktree
//
// When pi launches inside a git repo on a named branch, create a fresh
// worktree at <repo_parent>/<repo>-<branch>-<ts> on a new branch
// agent/<branch>-<ts>, then re-exec pi inside it. The parent pi blocks on
// the child via spawnSync so the user sees a single continuous process.
//
// Skip (pi runs normally) when:
//   - PI_WORKTREE_ALREADY=1 is set (we are the re-exec child)
//   - not inside a git repo
//   - HEAD is detached (no named branch)
//   - already inside a linked worktree (.git at toplevel is a regular file)
//
// The factory returns a Promise that never resolves on the worktree path:
// process.exit(child.status) ends the parent before pi proceeds with
// session_start, so AGENTS.md / MCP / system-prompt cwd are loaded fresh
// in the child against the worktree.

const RECURSION_GUARD = "PI_WORKTREE_ALREADY";

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

	const dotGit = join(toplevel, ".git");
	if (deps.statIsFile(dotGit)) {
		return { action: "skip", reason: "already in a linked worktree" };
	}

	const branchResult = await deps.exec("git", [
		"symbolic-ref",
		"--short",
		"HEAD",
	]);
	if (branchResult.code !== 0 || !branchResult.stdout.trim()) {
		return { action: "skip", reason: "detached HEAD" };
	}
	const branch = branchResult.stdout.trim();

	const safeBranch = branch.replace(/\//g, "-");
	const d = deps.now();
	const ts =
		`${d.getFullYear()}` +
		`${String(d.getMonth() + 1).padStart(2, "0")}` +
		`${String(d.getDate()).padStart(2, "0")}` +
		"-" +
		`${String(d.getHours()).padStart(2, "0")}` +
		`${String(d.getMinutes()).padStart(2, "0")}` +
		`${String(d.getSeconds()).padStart(2, "0")}`;
	const repoName = basename(toplevel);
	const worktreeDir = join(
		dirname(toplevel),
		`${repoName}-${safeBranch}-${ts}`,
	);
	const agentBranch = `agent/${safeBranch}-${ts}`;

	return {
		action: "worktree",
		worktreeDir,
		agentBranch,
		baseBranch: branch,
	};
}

export default async function (pi: ExtensionAPI) {
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

	const child = spawnSync("pi", process.argv.slice(2), {
		cwd: worktreeDir,
		stdio: "inherit",
		env: { ...process.env, [RECURSION_GUARD]: "1" },
	});
	process.exit(child.status ?? 0);
}

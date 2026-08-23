import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";

const REFRESH_INTERVAL_MS = 60_000;
const REQUEST_TIMEOUT_MS = 10_000;
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

type UsageWindow = {
	used_percent: number;
	reset_after_seconds: number;
};

type UsageSummary = {
	text: string;
	severity: "success" | "warning" | "error";
};

function isUsageWindow(value: unknown): value is UsageWindow {
	if (!value || typeof value !== "object") return false;
	const window = value as Record<string, unknown>;
	return typeof window.used_percent === "number" && typeof window.reset_after_seconds === "number";
}

function formatRemaining(seconds: number): string {
	const minutes = Math.max(0, Math.ceil(seconds / 60));
	const days = Math.floor(minutes / (24 * 60));
	const hours = Math.floor((minutes % (24 * 60)) / 60);
	const remainingMinutes = minutes % 60;

	if (days > 0) return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
	if (hours > 0) return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
	return `${remainingMinutes}m`;
}

function formatTokens(tokens: number): string {
	if (tokens < 1_000) return `${tokens}`;
	if (tokens < 1_000_000) return `${(tokens / 1_000).toFixed(tokens < 10_000 ? 1 : 0)}k`;
	return `${(tokens / 1_000_000).toFixed(1)}m`;
}

function summarizeUsage(payload: unknown): UsageSummary {
	if (!payload || typeof payload !== "object") throw new Error("Unexpected usage response");

	const rateLimit = (payload as { rate_limit?: unknown }).rate_limit;
	if (!rateLimit || typeof rateLimit !== "object") throw new Error("Usage response has no rate limit");

	const limit = rateLimit as { primary_window?: unknown; limit_reached?: unknown };
	if (!isUsageWindow(limit.primary_window)) throw new Error("Usage response has no primary window");

	const used = Math.min(100, Math.max(0, Math.round(limit.primary_window.used_percent)));
	const reached = limit.limit_reached === true;
	return {
		text: `Codex ${100 - used}% ↻ ${formatRemaining(limit.primary_window.reset_after_seconds)}`,
		severity: reached || used >= 100 ? "error" : used >= 80 ? "warning" : "success",
	};
}

async function fetchUsage(): Promise<UsageSummary> {
	const codexHome = process.env.CODEX_HOME || join(homedir(), ".codex");
	const auth = JSON.parse(await readFile(join(codexHome, "auth.json"), "utf8")) as {
		tokens?: { access_token?: unknown; account_id?: unknown };
	};
	const accessToken = auth.tokens?.access_token;
	const accountId = auth.tokens?.account_id;
	if (typeof accessToken !== "string" || typeof accountId !== "string") {
		throw new Error("Codex OAuth credentials are unavailable");
	}

	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
	try {
		const response = await fetch(USAGE_URL, {
			headers: {
				Authorization: `Bearer ${accessToken}`,
				"ChatGPT-Account-Id": accountId,
				"User-Agent": "pi-codex-usage-status/1.0",
			},
			signal: controller.signal,
		});
		if (!response.ok) throw new Error(`Codex usage request failed (${response.status})`);
		return summarizeUsage((await response.json()) as unknown);
	} finally {
		clearTimeout(timeout);
	}
}

function getSessionTokenTotals(ctx: ExtensionContext): { input: number; output: number } {
	let input = 0;
	let output = 0;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;
		const usage = (entry.message as AssistantMessage).usage;
		input += usage.input;
		output += usage.output;
	}
	return { input, output };
}

export default function (pi: ExtensionAPI) {
	let refreshTimer: ReturnType<typeof setInterval> | undefined;
	let stopped = false;
	let refreshing = false;
	let codexUsage: UsageSummary | undefined;
	let codexUnavailable = false;
	let gitDirty = false;
	let worktreeName: string | undefined;
	let requestFooterRender: (() => void) | undefined;

	async function refresh(ctx: ExtensionContext, notify = false): Promise<void> {
		if (refreshing) return;
		refreshing = true;
		try {
			codexUsage = await fetchUsage();
			codexUnavailable = false;
			if (!stopped && notify) {
				ctx.ui.notify(codexUsage.text, codexUsage.severity === "error" ? "error" : "info");
			}
		} catch {
			codexUsage = undefined;
			codexUnavailable = true;
			if (!stopped && notify) ctx.ui.notify("Codex usage unavailable", "warning");
		} finally {
			refreshing = false;
			if (!stopped) requestFooterRender?.();
		}
	}

	async function refreshGitStatus(cwd: string): Promise<void> {
		try {
			const [status, paths] = await Promise.all([
				pi.exec("git", ["status", "--porcelain"], { cwd, timeout: 5_000 }),
				pi.exec("git", ["rev-parse", "--git-dir", "--git-common-dir"], { cwd, timeout: 5_000 }),
			]);
			gitDirty = status.code === 0 && status.stdout.trim().length > 0;
			worktreeName = undefined;
			if (paths.code === 0) {
				const [gitDir, commonGitDir] = paths.stdout.trim().split(/\r?\n/);
				if (gitDir && commonGitDir && resolve(cwd, gitDir) !== resolve(cwd, commonGitDir)) {
					worktreeName = basename(resolve(cwd, gitDir));
				}
			}
		} catch {
			gitDirty = false;
			worktreeName = undefined;
		} finally {
			if (!stopped) requestFooterRender?.();
		}
	}

	pi.on("session_start", (_event, ctx) => {
		stopped = false;
		if (refreshTimer) clearInterval(refreshTimer);

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsubscribe = footerData.onBranchChange(() => {
				void refreshGitStatus(ctx.cwd);
				tui.requestRender();
			});
			requestFooterRender = () => tui.requestRender();

			return {
				dispose: () => {
					unsubscribe();
					requestFooterRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const totals = getSessionTokenTotals(ctx);
					const context = ctx.getContextUsage();
					const contextLimit = ctx.model?.contextWindow;
					const contextPercent =
						context && contextLimit ? Math.round((context.tokens / contextLimit) * 100) : undefined;
					const branch = footerData.getGitBranch();

					const codex = codexUsage
						? theme.fg(codexUsage.severity, codexUsage.text)
						: theme.fg(codexUnavailable ? "warning" : "dim", codexUnavailable ? "Codex unavailable" : "Codex loading…");
					const contextColor =
						contextPercent !== undefined && contextPercent >= 95
							? "error"
							: contextPercent !== undefined && contextPercent >= 80
								? "warning"
								: "accent";
					const contextText =
						contextPercent === undefined
							? theme.fg("dim", "ctx —")
							: (() => {
								const cells = 8;
								const filled = Math.round((contextPercent / 100) * cells);
								return (
									theme.fg("muted", "ctx ") +
									theme.fg(contextColor, "█".repeat(filled)) +
									theme.fg("dim", "░".repeat(cells - filled)) +
									theme.fg(contextColor, ` ${contextPercent}%`)
								);
							})();
					const model = ctx.model?.id ?? "no model";
					const tokenTotal = totals.input + totals.output;
					const tokenField =
						theme.fg("accent", `↑${formatTokens(totals.input)}`) +
						" " +
						theme.fg("success", `↓${formatTokens(totals.output)}`) +
						" " +
						theme.fg("muted", `Σ${formatTokens(tokenTotal)}`);
					const statuses = footerData.getExtensionStatuses();
					const fast = statuses.get("codex-fast");
					const extensionStatuses = [...statuses.entries()]
						.filter(([id]) => id !== "codex-fast")
						.map(([, status]) => status);
					const modelField =
						theme.fg("accent", model) +
						(fast ? ` ${theme.fg("warning", fast)}` : "") +
						theme.fg("accent", ` · ${ctx.thinkingLevel}`);
					const worktreeField = worktreeName ? theme.fg("accent", `⑂ ${worktreeName}`) : undefined;
					const gitField = branch
						? theme.fg(gitDirty ? "warning" : "dim", `git:${branch}${gitDirty ? "*" : ""}`) +
							(worktreeField ? ` ${worktreeField}` : "")
						: worktreeField;
					const fields = [
						codex,
						...extensionStatuses,
						theme.fg(contextColor, contextText),
						modelField,
						gitField,
					].filter((field): field is string => field !== undefined);
					const separator = theme.fg("dim", " | ");
					let left = "";
					for (const field of fields) {
						const candidate = left ? `${left}${separator}${field}` : field;
						if (visibleWidth(candidate) + 1 + visibleWidth(tokenField) > width) break;
						left = candidate;
					}
					const padding = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(tokenField)));
					return [truncateToWidth(`${left}${padding}${tokenField}`, width)];
				},
			};
		});

		void refresh(ctx);
		void refreshGitStatus(ctx.cwd);
		refreshTimer = setInterval(() => void refresh(ctx), REFRESH_INTERVAL_MS);
		refreshTimer.unref?.();
	});

	pi.on("agent_settled", (_event, ctx) => {
		void refreshGitStatus(ctx.cwd);
		requestFooterRender?.();
	});

	pi.on("model_select", () => requestFooterRender?.());
	pi.on("thinking_level_select", () => requestFooterRender?.());

	pi.on("session_shutdown", () => {
		stopped = true;
		if (refreshTimer) clearInterval(refreshTimer);
		refreshTimer = undefined;
	});

	pi.registerCommand("codex-usage", {
		description: "Refresh Codex usage in the status bar",
		handler: async (_args, ctx) => refresh(ctx, true),
	});
}

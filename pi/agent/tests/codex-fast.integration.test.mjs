import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { zstdDecompressSync } from "node:zlib";
import { test } from "node:test";

// Uses installed Pi + pi-subagents, but sends all model requests to a local stub.
const piBin = process.env.PI_TEST_BIN ?? (() => {
	try { return execFileSync("which", ["pi"], { encoding: "utf8" }).trim(); }
	catch { return undefined; }
})();
const packageRoot = piBin ? dirname(dirname(dirname(realpathSync(piBin)))) : undefined;
const runner = join(process.env.PI_SUBAGENTS_ROOT ?? join(homedir(), ".pi/agent/npm/node_modules/@tintinweb/pi-subagents"), "src/agent-runner.ts");

test("installed Pi and subagent runner send priority on the wire, including isolated children", {
	skip: !packageRoot || !existsSync(runner), timeout: 60_000,
}, async () => {
	const directory = mkdtempSync(join(tmpdir(), "codex-fast-test-"));
	const requests = [];
	const server = createServer(async (req, res) => {
		try {
			const chunks = [];
			for await (const chunk of req) chunks.push(chunk);
			const raw = Buffer.concat(chunks);
			const body = JSON.parse((req.headers["content-encoding"] === "zstd" ? zstdDecompressSync(raw) : raw).toString());
			requests.push({ model: body.model, tier: body.service_tier });
			const response = { id: `resp_${requests.length}`, status: "completed", service_tier: body.service_tier, output: [], usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 } };
			const events = [
				{ type: "response.created", response: { ...response, status: "in_progress" } },
				{ type: "response.output_item.added", output_index: 0, item: { type: "message", id: "msg_1", role: "assistant", content: [] } },
				{ type: "response.output_text.delta", output_index: 0, content_index: 0, delta: "OK" },
				{ type: "response.completed", response },
			];
			res.writeHead(200, { "content-type": "text/event-stream" });
			res.end(events.map((event) => `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`).join(""));
		} catch (error) {
			res.writeHead(500);
			res.end(String(error));
		}
	});
	await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
	const baseUrl = `http://127.0.0.1:${server.address().port}`;
	try {
		const agentDir = join(directory, "agent");
		mkdirSync(join(agentDir, "extensions"), { recursive: true });
		const extension = fileURLToPath(new URL("../extensions/codex-fast.ts", import.meta.url));
		symlinkSync(extension, join(agentDir, "extensions/codex-fast.ts"));
		writeFileSync(join(agentDir, "settings.json"), JSON.stringify({
			packages: [], transport: "sse", enableInstallTelemetry: false, defaultProjectTrust: "no",
			extensions: ["-builtin:mcp", "-builtin:llama.cpp", "-builtin:codemode", "-builtin:tool-search"],
		}));
		const fakeJwt = `e30.${Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "test-account" } })).toString("base64url")}.test`;
		const fixture = join(directory, "fixture.ts");
		writeFileSync(fixture, `
import { runAgent } from ${JSON.stringify(runner)};
export default function (pi) {
	for (const [provider, id, api, apiKey] of [
		["openai", "test-openai", "openai-responses", "sk-test"],
		["openai-codex", "test-codex", "openai-codex-responses", ${JSON.stringify(fakeJwt)}],
	]) pi.registerProvider(provider, {
		api, apiKey, baseUrl: ${JSON.stringify(baseUrl)},
		models: [{ id, name: id, reasoning: false, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 32 }],
	});
	pi.registerCommand("probe-child", {
		handler: async (args, ctx) => {
			const [modelName, mode] = args.split(" ");
			const [provider, id] = modelName.split("/");
			const model = ctx.modelRegistry.find(provider, id);
			const result = await runAgent(ctx, "general-purpose", "Reply only OK.", {
				pi, model, isolated: mode === "isolated", nested: true, maxTurns: 2, thinkingLevel: "off",
			});
			if (result.failure) throw new Error(result.failure);
			result.session.dispose();
		},
	});
	pi.on("session_shutdown", (_event, ctx) => {
		const tiers = ctx.sessionManager.getBranch().filter(e => e.type === "custom" && e.customType === "codex-fast-response").map(e => e.data);
		console.error("TIER_RESULTS=" + JSON.stringify(tiers));
	});
}
`);
		const args = [
			join(packageRoot, "dist/bundle/cli.js"), "--offline", "--no-session", "--no-extensions",
			"--no-tools", "--no-skills", "--no-prompt-templates", "--no-context-files",
			"-e", extension, "-e", fixture, "--model", "openai/test-openai", "--thinking", "off",
			"--system-prompt", "Reply only OK.", "-p", "/fast on", "Reply only OK.",
			"/probe-child openai/test-openai normal", "/probe-child openai/test-openai isolated",
			"/probe-child openai-codex/test-codex normal", "/probe-child openai-codex/test-codex isolated",
			"/fast off", "Reply only OK.", "/probe-child openai/test-openai isolated",
		];
		const child = spawn(process.execPath, args, {
			cwd: directory,
			env: { ...process.env, PI_CODING_AGENT_DIR: agentDir, PI_OFFLINE: "1" },
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stdout = "", stderr = "";
		child.stdout.on("data", (chunk) => { stdout += chunk; });
		child.stderr.on("data", (chunk) => { stderr += chunk; });
		const timeout = setTimeout(() => child.kill("SIGKILL"), 50_000);
		const code = await new Promise((resolve, reject) => {
			child.on("error", reject);
			child.on("close", resolve);
		}).finally(() => clearTimeout(timeout));
		assert.equal(code, 0, `${stdout}\n${stderr}`);
		assert.deepEqual(requests, [
			{ model: "test-openai", tier: "priority" },
			{ model: "test-openai", tier: "priority" },
			{ model: "test-openai", tier: "priority" },
			{ model: "test-codex", tier: "priority" },
			{ model: "test-codex", tier: "priority" },
			{ model: "test-openai", tier: "default" },
			{ model: "test-openai", tier: "default" },
		], `${stdout}\n${stderr}`);
		const line = stderr.split("\n").find((value) => value.startsWith("TIER_RESULTS="));
		assert.ok(line, stderr);
		const results = JSON.parse(line.slice("TIER_RESULTS=".length));
		assert.equal(results.length, requests.length);
		assert.ok(results.every((result) => result.requested === result.actual));
	} finally {
		server.closeAllConnections();
		await new Promise((resolve) => server.close(resolve));
		rmSync(directory, { recursive: true, force: true });
	}
});

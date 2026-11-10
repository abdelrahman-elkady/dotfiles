import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../extensions/codex-fast.ts";

let nextSession = 0;
function createRegistry() {
	const builtins = new Map();
	const native = new Map();
	for (const id of ["openai", "openai-codex", "anthropic", "openrouter"]) {
		const stream = (model, context, options = {}) => ({ model, context, options });
		builtins.set(id, { id, name: id, auth: {}, getModels: () => [], stream, streamSimple: stream });
	}
	return {
		getProvider: (name) => native.get(name) ?? builtins.get(name),
		getRegisteredNativeProvider: (name) => native.get(name),
		getRegisteredProviderConfig: () => undefined,
		register: (provider) => native.set(provider.id, provider),
		unregister: (name) => native.delete(name),
	};
}

function createHarness({ provider = "openai", api, entries = [], registry = createRegistry(), isolated = false } = {}) {
	const hooks = new Map();
	const commands = new Map();
	const notices = [];
	const statuses = new Map();
	const sessionId = `session-${++nextSession}`;
	const ctx = {
		model: {
			provider, id: "test-model",
			api: api ?? (provider === "openai-codex" ? "openai-codex-responses" : "openai-responses"),
		},
		modelRegistry: registry,
		hasUI: true,
		ui: {
			setStatus: (key, value) => statuses.set(key, value),
			notify: (message, level) => notices.push({ message, level }),
		},
		sessionManager: { getBranch: () => entries, getSessionId: () => sessionId },
	};
	if (!isolated) extension({
		on: (name, handler) => hooks.set(name, handler),
		registerCommand: (name, command) => commands.set(name, command),
		appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
		registerProvider: (provider) => registry.register(provider),
		unregisterProvider: (name) => registry.unregister(name),
	});
	const emit = (name, event = {}) => hooks.get(name)?.({ type: name, ...event }, ctx);
	const command = (value) => commands.get("fast").handler(value, ctx);
	let lastRequest;
	const request = async (payload = { model: ctx.model.id, input: [] }, overrides = {}, method = "streamSimple") => {
		lastRequest = registry.getProvider(provider)[method](ctx.model, { messages: [] }, { sessionId, ...overrides });
		const replacement = await lastRequest.options.onPayload?.(payload, ctx.model);
		return replacement === undefined ? payload : replacement;
	};
	const response = (tier, type = "response.completed") =>
		lastRequest.options.onProviderStreamEvent?.({ type, response: { service_tier: tier } }, ctx.model);
	emit("session_start", { reason: "startup" });
	return { ctx, registry, entries, notices, statuses, emit, command, request, response };
}

for (const provider of ["openai", "openai-codex"]) {
	for (const method of ["stream", "streamSimple"]) {
		test(`${provider}/${method}: off by default, on requests priority, off requests default`, async () => {
			const h = createHarness({ provider });
			assert.equal((await h.request(undefined, {}, method)).service_tier, "default");
			await h.command("on");
			assert.equal((await h.request(undefined, {}, method)).service_tier, "priority");
			await h.command("off");
			assert.equal((await h.request(undefined, {}, method)).service_tier, "default");
		});
	}
}

test("toggles, trims arguments, and rejects invalid commands without changing state", async () => {
	const h = createHarness();
	await h.command("");
	assert.equal((await h.request()).service_tier, "priority");
	await h.command(" TOGGLE ");
	assert.equal((await h.request()).service_tier, "default");
	await h.command("bad");
	assert.equal((await h.request()).service_tier, "default");
	assert.match(h.notices.at(-1).message, /Usage:/);
});

test("preserves the payload and runs after the caller's payload hook", async () => {
	const h = createHarness();
	await h.command("on");
	const input = Object.freeze({ model: "test-model", input: [], service_tier: "flex", stream: true });
	const onPayload = async (payload) => ({ ...payload, service_tier: "default", extra: true });
	assert.deepEqual(await h.request(input, { onPayload }), { ...input, extra: true, service_tier: "priority" });
	assert.equal(input.service_tier, "flex");
});

test("leaves unrelated providers and APIs alone", async () => {
	for (const [provider, api] of [["anthropic", "anthropic-messages"], ["openrouter", "openai-responses"], ["openai", "openai-completions"]]) {
		const h = createHarness({ provider, api });
		await h.command("on");
		const payload = { model: "test", service_tier: "flex" };
		assert.equal(await h.request(payload), payload);
	}
});

test("leaves malformed payloads and explicit null replacements unchanged", async () => {
	const h = createHarness();
	for (const payload of [null, [], "text", 42]) assert.equal(await h.request(payload), payload);
	assert.equal(await h.request({}, { onPayload: () => null }), null);
});

test("restores the session setting after reload and resume", async () => {
	const h = createHarness();
	await h.command("on");
	h.emit("session_shutdown", { reason: "reload" });
	const reloaded = createHarness({ entries: h.entries, registry: h.registry });
	assert.equal((await reloaded.request()).service_tier, "priority");
	reloaded.emit("session_shutdown", { reason: "quit" });
	const resumed = createHarness({ entries: h.entries });
	assert.equal((await resumed.request()).service_tier, "priority");
});

test("new sessions do not inherit the previous session's toggle", async () => {
	const h = createHarness();
	await h.command("on");
	h.emit("session_shutdown", { reason: "new" });
	const next = createHarness({ registry: h.registry });
	assert.equal((await next.request()).service_tier, "default");
});

test("tree navigation restores branch-local state", async () => {
	const h = createHarness();
	await h.command("on");
	const onEntries = [...h.entries];
	await h.command("off");
	h.entries.splice(0, h.entries.length, ...onEntries);
	h.emit("session_tree");
	assert.equal((await h.request()).service_tier, "priority");
});

test("normal, nested, and isolated in-process children share the parent's setting", async () => {
	const parent = createHarness();
	await parent.command("on");
	const child = createHarness({ registry: parent.registry });
	const grandchild = createHarness({ registry: child.registry });
	const isolated = createHarness({ registry: parent.registry, isolated: true });
	for (const h of [parent, child, grandchild, isolated]) {
		assert.equal((await h.request()).service_tier, "priority");
	}
	await parent.command("off");
	for (const h of [parent, child, grandchild, isolated]) {
		assert.equal((await h.request()).service_tier, "default");
	}
});

test("loading and disposing children does not reset the parent's policy", async () => {
	const parent = createHarness();
	await parent.command("on");
	const child = createHarness({ registry: parent.registry });
	child.emit("session_tree");
	child.emit("session_shutdown", { reason: "quit" });
	assert.equal((await parent.request()).service_tier, "priority");
});

test("unrelated runtimes have independent settings", async () => {
	const first = createHarness();
	const second = createHarness();
	await first.command("on");
	assert.equal((await first.request()).service_tier, "priority");
	assert.equal((await second.request()).service_tier, "default");
});

test("status does not claim server confirmation before a response", async () => {
	const h = createHarness();
	await h.command("on");
	await h.request();
	await h.command("status");
	assert.match(h.notices.at(-1).message, /not confirmed/i);
});

for (const tier of ["priority", "fast"]) {
	test(`records a server-confirmed ${tier} response`, async () => {
		const h = createHarness();
		await h.command("on");
		await h.request();
		await h.response(tier);
		await h.command("status");
		assert.match(h.notices.at(-1).message, new RegExp(`${tier}.*fast confirmed`, "i"));
		assert.ok(h.entries.some((entry) => entry.customType === "codex-fast-response" && entry.data.actual === tier));
	});
}

test("reports subagent tier confirmations in the parent, including isolated children", async () => {
	const parent = createHarness();
	await parent.command("on");
	const child = createHarness({ registry: parent.registry, isolated: true });
	await child.request();
	await child.response("priority");
	await parent.command("status");
	assert.match(parent.notices.at(-1).message, /Main: not confirmed.*Subagent: priority \(fast confirmed\)/);
	assert.equal(parent.entries.at(-1).data.sessionId, child.ctx.sessionManager.getSessionId());
});

test("reports a server downgrade rather than claiming fast mode succeeded", async () => {
	const h = createHarness();
	await h.command("on");
	await h.request();
	await h.response("default");
	assert.ok(h.notices.some(({ message, level }) => level === "warning" && /default/.test(message)));
	await h.command("status");
	assert.match(h.notices.at(-1).message, /Main: default/);
	assert.doesNotMatch(h.notices.at(-1).message, /fast confirmed/i);
});

test("a response without a tier stays unconfirmed", async () => {
	const h = createHarness();
	await h.command("on");
	await h.request();
	await h.response(undefined, "response.done");
	await h.command("status");
	assert.match(h.notices.at(-1).message, /not confirmed/i);
});

test("preserves existing observers and records the tier only once", async () => {
	const h = createHarness();
	let observed = 0;
	await h.request(undefined, { onProviderStreamEvent: () => { observed++; } });
	await h.response("default");
	await h.response("default", "response.done");
	assert.equal(observed, 2);
	assert.equal(h.entries.filter((entry) => entry.customType === "codex-fast-response").length, 1);
});

test("in-flight requests retain the requested tier across toggles", async () => {
	const h = createHarness();
	await h.command("on");
	await h.request();
	await h.command("off");
	await h.response("priority");
	assert.equal(h.entries.at(-1).data.requested, "priority");
	assert.equal((await h.request()).service_tier, "default");
});

test("shutdown restores previous native providers without overwriting later registrations", () => {
	const registry = createRegistry();
	const original = { ...registry.getProvider("openai") };
	registry.register(original);
	const h = createHarness({ registry });
	const replacement = { ...registry.getProvider("openai-codex") };
	registry.register(replacement);
	h.emit("session_shutdown", { reason: "quit" });
	assert.equal(registry.getRegisteredNativeProvider("openai"), original);
	assert.equal(registry.getRegisteredNativeProvider("openai-codex"), replacement);
});

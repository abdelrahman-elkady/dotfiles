import type { Api, Model, Provider, StreamOptions } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATE_ENTRY = "codex-fast";
const RESPONSE_ENTRY = "codex-fast-response";
const POLICY_KEY = Symbol.for("kady.pi.codex-fast.policy");
const PROVIDERS = ["openai", "openai-codex"] as const;

type FastCommand = "on" | "off" | "toggle" | "status";
type TierResult = {
	provider: string;
	model: string;
	sessionId?: string;
	requested: "priority" | "default";
	actual: string | null;
};
type Policy = {
	enabled: boolean;
	active: boolean;
	lastMain?: TierResult;
	lastSubagent?: TierResult;
	setEnabled: (enabled: boolean) => void;
	record: (result: TierResult) => void;
};
type TaggedProvider = Provider & { [POLICY_KEY]?: Policy };

function isRecord(value: unknown): value is Record<string, unknown> {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function supportsFast(model: Model<Api> | undefined): boolean {
	return (
		(model?.provider === "openai" && model.api === "openai-responses") ||
		(model?.provider === "openai-codex" && model.api === "openai-codex-responses")
	);
}

function isFastTier(tier: string | null): boolean {
	return tier === "priority" || tier === "fast";
}

function describeResult(result: TierResult | undefined): string {
	if (!result) return "not confirmed yet";
	if (!result.actual) return "not confirmed (server omitted tier)";
	return `${result.actual}${isFastTier(result.actual) ? " (fast confirmed)" : ""}`;
}

export default function (pi: ExtensionAPI) {
	let policy: Policy | undefined;
	let ownsPolicy = false;
	let restoreProviders: (() => void)[] = [];

	function updateStatus(ctx: ExtensionContext): void {
		const actual = policy?.lastMain?.actual;
		const status = supportsFast(ctx.model) && policy?.enabled
			? actual && !isFastTier(actual) ? `tier: ${actual} (fast requested)` : `fast: ${actual ?? "requested"}`
			: undefined;
		ctx.ui.setStatus(STATE_ENTRY, status);
	}

	function restoreState(ctx: ExtensionContext): void {
		if (!policy || !ownsPolicy) return;
		policy.enabled = false;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === STATE_ENTRY && isRecord(entry.data)) {
				if (typeof entry.data.enabled === "boolean") policy.enabled = entry.data.enabled;
			}
		}
		policy.lastMain = undefined;
		policy.lastSubagent = undefined;
		updateStatus(ctx);
	}

	pi.registerCommand("fast", {
		description: "Toggle OpenAI/Codex fast mode for the main agent and subagents",
		getArgumentCompletions: (prefix) => {
			const commands: FastCommand[] = ["on", "off", "toggle", "status"];
			return commands
				.filter((command) => command.startsWith(prefix.trim().toLowerCase()))
				.map((command) => ({ value: command, label: command }));
		},
		handler: async (args, ctx) => {
			const command = args.trim().toLowerCase();
			if (!["", "on", "off", "toggle", "status"].includes(command)) {
				ctx.ui.notify("Usage: /fast [on|off|toggle|status]", "warning");
				return;
			}
			if (!policy) {
				ctx.ui.notify("Fast mode is not initialized. Run /reload.", "warning");
				return;
			}
			if (command !== "status") {
				policy.setEnabled(command === "on" || (command !== "off" && !policy.enabled));
			}
			updateStatus(ctx);
			const setting = `Fast ${policy.enabled ? "requested (priority)" : "off (default)"} for main + subagents.`;
			const result = `Main: ${describeResult(policy.lastMain)}. Subagent: ${describeResult(policy.lastSubagent)}.`;
			const note = supportsFast(ctx.model) ? "" : " Current model is not an OpenAI/Codex Responses model.";
			ctx.ui.notify(`${setting} ${result}${note}`, "info");
		},
	});

	pi.on("session_start", (_event, ctx) => {
		// pi-subagents 0.23 shares the parent's ModelRuntime, even for isolated children.
		// Reuse its policy; a fresh child extension must not reset or replace it.
		for (const name of PROVIDERS) {
			const inherited = (ctx.modelRegistry.getRegisteredNativeProvider(name) as TaggedProvider | undefined)?.[POLICY_KEY];
			if (inherited?.active) {
				policy = inherited;
				updateStatus(ctx);
				return;
			}
		}

		ownsPolicy = true;
		const owner = ctx.sessionManager.getSessionId();
		const shared: Policy = {
			enabled: false,
			active: true,
			setEnabled(enabled) {
				shared.enabled = enabled;
				shared.lastMain = undefined;
				shared.lastSubagent = undefined;
				pi.appendEntry(STATE_ENTRY, { enabled });
				updateStatus(ctx);
			},
			record(result) {
				if (!shared.active) return;
				if (result.sessionId === owner) shared.lastMain = result;
				else shared.lastSubagent = result;
				// Persist tier metadata only, never prompts, response text, or credentials.
				pi.appendEntry(RESPONSE_ENTRY, result);
				updateStatus(ctx);
				if (result.requested === "priority" && result.actual && !isFastTier(result.actual)) {
					ctx.ui.notify(`Requested priority for ${result.model}, but the server used ${result.actual}.`, "warning");
				}
			},
		};
		policy = shared;
		restoreState(ctx);

		function withTier(model: Model<Api>, options: StreamOptions = {}): StreamOptions {
			if (!supportsFast(model) || !shared.active) return options;
			// Snapshot per request: toggling never relabels a request already in flight.
			const requested = shared.enabled ? "priority" : "default";
			let recorded = false;
			return {
				...options,
				onPayload: async (payload, requestModel) => {
					const replacement = await options.onPayload?.(payload, requestModel);
					const outgoing = replacement === undefined ? payload : replacement;
					// Run last, including after child extension hooks.
					return isRecord(outgoing) ? { ...outgoing, service_tier: requested } : outgoing;
				},
				onProviderStreamEvent: async (data, responseModel) => {
					await options.onProviderStreamEvent?.(data, responseModel);
					if (recorded || !isRecord(data) || (data.type !== "response.completed" && data.type !== "response.done")) return;
					recorded = true;
					const actual = isRecord(data.response) && typeof data.response.service_tier === "string"
						? data.response.service_tier : null;
					shared.record({ provider: model.provider, model: model.id, sessionId: options.sessionId, requested, actual });
				},
			};
		}

		for (const name of PROVIDERS) {
			const original = ctx.modelRegistry.getProvider(name);
			if (!original) continue;
			const previousNative = ctx.modelRegistry.getRegisteredNativeProvider(name);
			const previousConfig = ctx.modelRegistry.getRegisteredProviderConfig(name);
			const wrapped: TaggedProvider = {
				...original,
				[POLICY_KEY]: shared,
				stream: (model, context, options) => original.stream(model, context, withTier(model, options) as typeof options),
				streamSimple: (model, context, options) => original.streamSimple(model, context, withTier(model, options)),
			};
			pi.registerProvider(wrapped);
			restoreProviders.push(() => {
				if (ctx.modelRegistry.getRegisteredNativeProvider(name) !== wrapped) return;
				if (previousNative) pi.registerProvider(previousNative);
				else {
					pi.unregisterProvider(name);
					if (previousConfig) pi.registerProvider(name, previousConfig);
				}
			});
		}
	});

	pi.on("session_tree", (_event, ctx) => restoreState(ctx));
	pi.on("model_select", (_event, ctx) => {
		if (policy && ownsPolicy) policy.lastMain = undefined;
		updateStatus(ctx);
	});
	pi.on("session_shutdown", (_event, ctx) => {
		if (policy && ownsPolicy) policy.active = false;
		for (const restore of restoreProviders.reverse()) restore();
		restoreProviders = [];
		ctx.ui.setStatus(STATE_ENTRY, undefined);
	});
}

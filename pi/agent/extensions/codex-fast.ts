import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_ID = "codex-fast";
const CODEX_PROVIDER = "openai-codex";

type FastCommand = "on" | "off" | "toggle" | "status";

export default function (pi: ExtensionAPI) {
	let enabled = false;

	function isCodex(ctx: ExtensionContext): boolean {
		return ctx.model?.provider === CODEX_PROVIDER;
	}

	function updateStatus(ctx: ExtensionContext): void {
		ctx.ui.setStatus(STATUS_ID, isCodex(ctx) && enabled ? "fast" : undefined);
	}

	pi.registerCommand("fast", {
		description: "Toggle Codex fast mode",
		getArgumentCompletions: (prefix) => {
			const commands: FastCommand[] = ["on", "off", "toggle", "status"];
			return commands
				.filter((command) => command.startsWith(prefix.trim().toLowerCase()))
				.map((command) => ({ value: command, label: command }));
		},
		handler: async (args, ctx) => {
			const command = args.trim().toLowerCase() as FastCommand | "";
			if (command === "on") enabled = true;
			else if (command === "off") enabled = false;
			else if (command === "" || command === "toggle") enabled = !enabled;
			else if (command !== "status") {
				ctx.ui.notify("Usage: /fast [on|off|toggle|status]", "warning");
				return;
			}

			updateStatus(ctx);
			if (!isCodex(ctx)) {
				ctx.ui.notify("Fast mode only applies to the openai-codex provider", "warning");
				return;
			}
			ctx.ui.notify(`Codex fast mode ${enabled ? "enabled" : "disabled"}`, "info");
		},
	});

	pi.on("session_start", (_event, ctx) => updateStatus(ctx));
	pi.on("model_select", (_event, ctx) => updateStatus(ctx));

	pi.on("before_provider_request", (event, ctx) => {
		if (!isCodex(ctx) || !event.payload || typeof event.payload !== "object" || Array.isArray(event.payload)) {
			return;
		}

		return {
			...(event.payload as Record<string, unknown>),
			service_tier: enabled ? "priority" : "default",
		};
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setStatus(STATUS_ID, undefined);
	});
}

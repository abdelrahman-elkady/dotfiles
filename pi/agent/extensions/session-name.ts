import {
	CustomEditor,
	type ExtensionAPI,
	type KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import {
	truncateToWidth,
	visibleWidth,
	type EditorTheme,
	type TUI,
} from "@earendil-works/pi-tui";

const MAX_SESSION_NAME_WIDTH = 60;

class SessionNameEditor extends CustomEditor {
	constructor(
		tui: TUI,
		theme: EditorTheme,
		keybindings: KeybindingsManager,
		private readonly getSessionName: () => string | undefined,
		private readonly styleSessionName: (text: string) => string,
	) {
		super(tui, theme, keybindings);
	}

	override render(width: number): string[] {
		const lines = super.render(width);
		const sessionName = this.getSessionName()?.replace(/[\r\n]+/g, " ").trim();
		if (!sessionName || lines.length === 0 || width < 6) return lines;

		const maxNameWidth = Math.min(MAX_SESSION_NAME_WIDTH, width - 4);
		const displayName = truncateToWidth(sessionName, maxNameWidth, "…");
		const label = ` ${displayName} `;
		const trailingBorder = this.borderColor("─");
		const leadingWidth = Math.max(0, width - visibleWidth(label) - visibleWidth(trailingBorder));

		lines[0] =
			truncateToWidth(lines[0] ?? "", leadingWidth, "") +
			this.styleSessionName(label) +
			trailingBorder;
		return lines;
	}
}

export default function (pi: ExtensionAPI) {
	let requestRender: (() => void) | undefined;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setEditorComponent((tui, editorTheme, keybindings) => {
			requestRender = () => tui.requestRender();
			return new SessionNameEditor(
				tui,
				editorTheme,
				keybindings,
				() => pi.getSessionName(),
				(text) => {
					const theme = ctx.ui.theme;
					return theme.inverse(theme.fg("borderAccent", text));
				},
			);
		});
	});

	pi.on("session_info_changed", () => requestRender?.());

	pi.on("session_shutdown", () => {
		requestRender = undefined;
	});
}

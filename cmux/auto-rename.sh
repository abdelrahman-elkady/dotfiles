# ==========================================
# cmux Auto-Renaming (Mimicking tmux logic)
# ==========================================

# Only run if we are in cmux AND NOT inside VS Code's integrated terminal AND
# NOT inside tmux. (A tmux server started from within cmux bakes
# CMUX_WORKSPACE_ID into its environment and leaks it to every pane — including
# ones later opened from iTerm2 — so $CMUX_WORKSPACE_ID alone isn't enough.)
if [[ -n "$CMUX_WORKSPACE_ID" ]] && [[ "$TERM_PROGRAM" != "vscode" ]] && [[ -z "$TMUX" ]]; then

    # State variable to track if auto-rename is enabled for this session
    export CMUX_AUTO_RENAME_ENABLED=1

    # Command to manually set a title and pause auto-renaming
    function ctitle() {
        export CMUX_AUTO_RENAME_ENABLED=0
        cmux rename-workspace "$*" > /dev/null 2>&1
        echo "Auto-renaming paused. Title locked to: $*"
    }

    # Command to resume auto-renaming
    function cauto() {
        export CMUX_AUTO_RENAME_ENABLED=1
        _CMUX_RENAME_LAST_PWD=""
        _cmux_rename_idle
        echo "Auto-renaming resumed."
    }

    # Rename the workspace to the current directory's basename, on every prompt.
    # (We intentionally do NOT track the running command via a DEBUG trap: bash
    # allows only one DEBUG trap and starship already uses it for command timing.)
    function _cmux_rename_idle() {
        [[ "$CMUX_AUTO_RENAME_ENABLED" == "0" ]] && return
        [[ "$PWD" == "$_CMUX_RENAME_LAST_PWD" ]] && return
        _CMUX_RENAME_LAST_PWD="$PWD"
        cmux rename-workspace "${PWD##*/}" > /dev/null 2>&1
    }

    # Safely append to PROMPT_COMMAND to prevent infinite duplication in subshells.
    # Use :+ so the separating ';' is only added when PROMPT_COMMAND is non-empty,
    # otherwise a leading ';' produces "syntax error near unexpected token ';'".
    if [[ "$PROMPT_COMMAND" != *"_cmux_rename_idle"* ]]; then
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_cmux_rename_idle"
    fi
fi

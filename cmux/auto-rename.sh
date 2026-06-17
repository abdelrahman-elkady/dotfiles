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
        _cmux_rename_idle
        echo "Auto-renaming resumed."
    }

    # Triggered when the shell is idle (waiting for input)
    function _cmux_rename_idle() {
        # Install the DEBUG trap *only* after the shell has fully loaded
        # This prevents the trap from firing thousands of times during .bashrc/NVM initialization!
        if [[ "$_CMUX_TRAP_INSTALLED" != "1" ]]; then
            export _CMUX_TRAP_INSTALLED=1
            trap '_cmux_rename_running' DEBUG
        fi

        if [[ "$CMUX_AUTO_RENAME_ENABLED" == "0" ]]; then return; fi
        cmux rename-workspace "${PWD##*/}" > /dev/null 2>&1
    }

    # Triggered right before a command starts executing
    function _cmux_rename_running() {
        if [[ "$CMUX_AUTO_RENAME_ENABLED" == "0" ]]; then return; fi
        
        local cmd="$BASH_COMMAND"
        local dir_name="${PWD##*/}"

        # Ignore silent prompt evaluations and background scripts
        if [[ "$cmd" == _cmux_* ]] || [[ "$cmd" == printf* ]] || [[ "$cmd" == starship* ]] || [[ "$cmd" == _emit_osc7* ]]; then
            return
        fi

        # Check the running command and format accordingly
        if [[ "$cmd" == *"claude"* ]]; then
            (cmux rename-workspace "[✴]$dir_name" > /dev/null 2>&1 &)
        elif [[ "$cmd" == *"agy"* ]]; then
            (cmux rename-workspace "[Δ]$dir_name" > /dev/null 2>&1 &)
        else
            # For anything else, extract just the first word of the command
            (cmux rename-workspace "${cmd%% *}" > /dev/null 2>&1 &)
        fi
    }

    # Safely append to PROMPT_COMMAND to prevent infinite duplication in subshells.
    # Use :+ so the separating ';' is only added when PROMPT_COMMAND is non-empty,
    # otherwise a leading ';' produces "syntax error near unexpected token ';'".
    if [[ "$PROMPT_COMMAND" != *"_cmux_rename_idle"* ]]; then
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_cmux_rename_idle"
    fi
fi

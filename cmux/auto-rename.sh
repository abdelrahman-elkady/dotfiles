# ==========================================
# cmux Auto-Renaming (Mimicking tmux logic)
# ==========================================
if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
    
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
        if [[ "$cmd" == *claude* ]]; then
            cmux rename-workspace "[✴]$dir_name" > /dev/null 2>&1
        elif [[ "$cmd" == *agy* ]]; then
            cmux rename-workspace "[Δ]$dir_name" > /dev/null 2>&1
        else
            # For anything else, extract just the first word of the command
            cmux rename-workspace "${cmd%% *}" > /dev/null 2>&1
        fi
    }

    # PROMPT_COMMAND handles the idle state (re-apply to just directory name)
    PROMPT_COMMAND="${PROMPT_COMMAND:-};_cmux_rename_idle"
    
    # Trap DEBUG handles the active running state
    trap '_cmux_rename_running' DEBUG
fi

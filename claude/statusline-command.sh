#!/usr/bin/env bash
# Claude Code status line — mirrors color_my_prompt / Starship style
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten a path to its last two components, prefixing with an ellipsis when the
# original had MORE than two components (to indicate truncation). Uses parameter
# expansion only — no external processes.
#   /Users/kady/dotfiles         -> …/kady/dotfiles
#   /Users/kady/projects/foo/bar -> …/foo/bar
#   /Users/kady                  -> /Users/kady   (exactly 2 components)
#   /foo                         -> /foo          (1 component)
#   /                            -> /
short_path() {
    local p=$1
    # Root is a special case.
    [ "$p" = "/" ] && { printf '/'; return; }
    # Strip a single trailing slash (but never reduce "/" to "").
    p=${p%/}
    [ -z "$p" ] && { printf '/'; return; }
    local last=${p##*/}            # last component
    local parent=${p%/*}           # everything before the last component
    local second=${parent##*/}     # second-to-last component
    # Count components by splitting on "/". Drop the leading slash, then count
    # remaining segments via word-splitting on "/".
    local rest=${p#/} count=0 seg
    local IFS=/
    for seg in $rest; do
        [ -n "$seg" ] && count=$((count + 1))
    done
    if [ "$count" -le 2 ]; then
        printf '%s' "$p"
    else
        printf '…/%s/%s' "$second" "$last"
    fi
}

# Shortened cwd for DISPLAY only. The original full $cwd is still passed to git.
cwd_display=$(short_path "$cwd")

# git branch (skip optional lock)
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
git_part=""
[ -n "$git_branch" ] && git_part=" (${git_branch})"

# Time remaining in the 5-hour rate-limit window, formatted as "Xh Ym".
# Sourced from .rate_limits.five_hour.resets_at (Unix epoch seconds). Left empty
# when the field is absent or the window has already reset (rem <= 0), so the ctx
# segment degrades cleanly to the plain graded "ctx:N%".
five_hour_remaining=""
five_hour_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_hour_resets_at" ]; then
    now=$(date +%s)
    rem=$(( five_hour_resets_at - now ))
    if [ "$rem" -gt 0 ] 2>/dev/null; then
        rem_h=$(( rem / 3600 ))
        rem_m=$(( (rem % 3600) / 60 ))
        five_hour_remaining="${rem_h}h ${rem_m}m"
    fi
fi

# context usage (color-graded by percentage)
ctx_part=""
ctx_rendered=""
if [ -n "$ctx_used" ]; then
    ctx_pct="$(printf '%.0f' "$ctx_used")"
    ctx_part=" ctx:${ctx_pct}%"
    # Pick a color based on the integer part of the percentage.
    ctx_int=${ctx_used%%.*}
    if [ "$ctx_int" -ge 20 ] 2>/dev/null; then
        ctx_color='\033[01;31m'        # red
    elif [ "$ctx_int" -ge 15 ] 2>/dev/null; then
        ctx_color='\033[1;38;5;208m'   # orange (256-color)
    elif [ "$ctx_int" -ge 10 ] 2>/dev/null; then
        ctx_color='\033[01;33m'        # yellow
    else
        ctx_color='\033[01;32m'        # green
    fi
fi

# 5-hour session rate-limit usage (color-graded by percentage)
# NOTE: the limit text has NO leading space of its own — the join logic below
# supplies exactly one leading space (via the inner separator when ctx is
# present, or an explicit single space when ctx is absent).
five_hour_part=""
five_hour_rendered=""
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five_hour_pct" ]; then
    five_hour_part="limit:$(printf '%.0f' "$five_hour_pct")%"
    # Pick a color based on the integer part of the percentage.
    five_hour_int=${five_hour_pct%%.*}
    if [ "$five_hour_int" -ge 90 ] 2>/dev/null; then
        five_hour_color='\033[01;31m'        # red
    elif [ "$five_hour_int" -ge 75 ] 2>/dev/null; then
        five_hour_color='\033[1;38;5;208m'   # orange (256-color)
    elif [ "$five_hour_int" -ge 50 ] 2>/dev/null; then
        five_hour_color='\033[01;33m'        # yellow
    else
        five_hour_color='\033[01;32m'        # green
    fi
    # Pre-render the limit segment.
    #   - With a known 5-hour reset time: "limit:(N% - Xh Ym remaining)" where
    #     "limit:(N%" keeps the graded color and " - Xh Ym remaining)" is dim
    #     grey.
    #   - Otherwise (no reset / window reset): plain graded "limit:N%".
    if [ -n "$five_hour_remaining" ]; then
        five_hour_rendered="${five_hour_color}limit:($(printf '%.0f' "$five_hour_pct")%\033[00m\033[02;37m - ${five_hour_remaining} remaining)\033[00m"
    else
        five_hour_rendered="${five_hour_color}${five_hour_part}\033[00m"
    fi
fi

# Inner separator between the ctx and limit segments — only when both exist.
# Light grey thin vertical bar (256-color) with one space on each side; this is
# the SUBTLE divider used *inside* the metrics group. It also supplies the single
# leading space before the (now space-less) limit segment.
ctx_limit_sep=""
if [ -n "$ctx_part" ] && [ -n "$five_hour_part" ]; then
    ctx_limit_sep=' \033[38;5;244m•\033[00m '
fi

# ctx text without its baked-in leading space; inside the metrics group the
# group divider's padding controls the left spacing, so the segment must not
# carry its own leading space (otherwise we'd get an asymmetric divider).
ctx_text="${ctx_part# }"

# Pre-render the ctx segment: plain graded "ctx:N%" (no parentheses, no
# remaining-time text). The remaining-time parenthetical now lives on the limit
# segment instead.
if [ -n "$ctx_part" ]; then
    ctx_rendered="${ctx_color}${ctx_text}\033[00m"
fi

# Assemble the metrics group (ctx + inner separator + limit) as a pre-rendered
# string carrying its own color escapes (emitted via %b later). No leading space
# of its own — the preceding group divider supplies the padding.
#   - both present : "<ctx> │ <limit>"   (inner sep controls inner spacing)
#   - ctx only     : "<ctx>"
#   - limit only   : "<limit>"
metrics_group=""
if [ -n "$ctx_part" ] && [ -n "$five_hour_part" ]; then
    metrics_group="${ctx_rendered}${ctx_limit_sep}${five_hour_rendered}"
elif [ -n "$ctx_part" ]; then
    metrics_group="${ctx_rendered}"
elif [ -n "$five_hour_part" ]; then
    metrics_group="${five_hour_rendered}"
fi

# Prominent group divider between the identity group and the metrics group.
# Heavy vertical bar (U+2503) in a medium-bright grey (256-color) padded with two
# spaces on each side, deliberately DISTINCT from the subtle thin "│" used inside
# the metrics group. Only render when the metrics group is non-empty.
group_divider=""
[ -n "$metrics_group" ] && group_divider='  \033[38;5;245m┃\033[00m  '

# session duration in minutes (white/default)
duration_part=""
duration_ms=$(echo "$input" | jq -r '.total_duration_ms // empty')
if [ -n "$duration_ms" ] && [ "$duration_ms" != "0" ]; then
    duration_min=$(( ${duration_ms%.*} / 60000 ))
    duration_part=" ${duration_min}m"
fi

# token usage segment (blue total, grey detail) — omitted when fields absent
token_part=""
tok_r=$(echo "$input"   | jq -r '.context_window.current_usage.input_tokens // empty')
tok_w=$(echo "$input"   | jq -r '.context_window.current_usage.output_tokens // empty')
tok_cr=$(echo "$input"  | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
tok_cw=$(echo "$input"  | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
if [ -n "$tok_r" ] && [ -n "$tok_w" ] && [ -n "$tok_cr" ] && [ -n "$tok_cw" ]; then
    # helper: format a number with k suffix
    fmt_k() {
        local n=$1
        if [ "$n" -ge 1000 ]; then
            printf '%dk' "$(( (n + 500) / 1000 ))"
        else
            printf '%d' "$n"
        fi
    }
    total=$(( tok_r + tok_w + tok_cr + tok_cw ))
    total_fmt=$(fmt_k "$total")
    r_fmt=$(fmt_k "$tok_r")
    w_fmt=$(fmt_k "$tok_w")
    cr_fmt=$(fmt_k "$tok_cr")
    cw_fmt=$(fmt_k "$tok_cw")
    # color-grade "total:X" by the RAW total token count; dim/grey for the rest
    if [ "$total" -ge 200000 ] 2>/dev/null; then
        total_color='\033[01;31m'        # red
    elif [ "$total" -ge 150000 ] 2>/dev/null; then
        total_color='\033[1;38;5;208m'   # orange (256-color)
    elif [ "$total" -ge 100000 ] 2>/dev/null; then
        total_color='\033[01;33m'        # yellow
    else
        total_color='\033[01;32m'        # green
    fi
    token_part=" ${total_color}total:${total_fmt}\033[00m\033[02;37m • r:${r_fmt} • w:${w_fmt} • cr:${cr_fmt} • cw:${cw_fmt}\033[00m"
fi

# Build the left-hand part (everything except the token segment) into a string.
#   GROUP 1 (identity): cwd (blue), branch (red), model (yellow)
#   GROUP DIVIDER     : "  ┃  " (medium grey, prominent) — only when metrics exist
#   GROUP 2 (metrics) : ctx (green) │ limit (color-graded) — pre-rendered above
#   duration segment  : appended after the metrics group (rare)
# The group divider and metrics group are passed via %b since they already carry
# their own \033[...] color escapes as literal text. The line now STARTS with the
# (shortened) path — no user@host segment.
left_part=$(printf "\033[01;34m%s\033[00m\033[31m%s\033[00m\033[01;33m %s\033[00m%b%b\033[00m%s" \
    "$cwd_display" "$git_part" "$model" "$group_divider" "$metrics_group" "$duration_part")

# Expand escape sequences in the token segment so we can measure/print it.
right_part=$(printf '%b' "$token_part")

# Compute the separator between left and right parts.
# Default to a single space (current behavior / narrow-terminal fallback).
separator=" "

if [ -n "$right_part" ]; then
    # Determine terminal width. stdout is not a TTY, so query /dev/tty.
    width=$(tput cols 2>/dev/null < /dev/tty)
    [ -z "$width" ] && width=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
    [ -z "$width" ] && width=${COLUMNS:-0}

    # Strip ANSI escape sequences to measure visible length.
    strip_ansi() { printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g'; }
    left_visible=$(strip_ansi "$left_part")
    right_visible=$(strip_ansi "$right_part")

    # Claude Code's status line render area is slightly narrower than the raw
    # terminal width, so reserve a small safety margin to avoid clipping the
    # right-aligned token segment. Tune MARGIN if the segment still clips/floats.
    MARGIN=4

    if [ "$width" -gt 0 ] 2>/dev/null; then
        eff_width=$(( width - MARGIN ))
        padding=$(( eff_width - ${#left_visible} - ${#right_visible} ))
        if [ "$padding" -ge 1 ]; then
            separator=$(printf '%*s' "$padding" '')
        fi
    fi
fi

if [ -n "$right_part" ]; then
    printf '%s%s%s' "$left_part" "$separator" "$right_part"
else
    printf '%s' "$left_part"
fi

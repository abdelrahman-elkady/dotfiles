#!/usr/bin/env bash
# Claude Code status line — two-line, Starship-flavoured.
#
#   line 1:  MODEL │  branch │ Context: [████▒▒▒▒▒▒] 250k/1M (25%)      limit:(N% - Xh Ym remaining)
#   line 2:  repo-anchored cwd  (full path with ~ when outside a git repo)
#
# The context bar replaces the old separate ctx% and token-breakdown segments:
# its fill length tracks the % of the window used, while its colour is graded by
# the RAW used-token count (the same 100k/150k/200k thresholds we've always used).
# The right-aligned 5-hour limit segment is kept verbatim from the old line.
#
# This runs on every render, so the helpers below set $REPLY (or use `printf -v`)
# instead of printing — call sites avoid a $()-subshell fork on the hot path.
input=$(</dev/stdin)

# ── Tunables ────────────────────────────────────────────────────────────────
BAR_WIDTH=20          # cells in the context bar
BAR_FILL='█'          # filled cell  (U+2588)
BAR_EMPTY='▒'         # empty cell   (U+2592)
BRANCH_GLYPH=$'\xee\x82\xa0'  # U+E0A0 powerline branch — byte-encoded so this PUA glyph survives editors; rendered via the PowerlineSymbols font
MARGIN=4              # right-align safety margin (Claude's render area < raw cols)

# ── Colours (literal \033 — expanded with %b at print time) ──────────────────
C_RESET='\033[00m'
C_MODEL='\033[01;33m'        # yellow bold
C_BRANCH='\033[31m'          # red
C_CWD='\033[01;34m'          # blue bold
C_GREY='\033[38;5;245m'      # separators / labels
C_DIM='\033[02;37m'          # dim grey numerals
C_EMPTY='\033[38;5;240m'     # unfilled bar cells
GRADE_GREEN='\033[01;32m'
GRADE_YELLOW='\033[01;33m'
GRADE_ORANGE='\033[1;38;5;208m'
GRADE_RED='\033[01;31m'

sep=" ${C_GREY}│${C_RESET} "  # inter-segment divider on line 1

# ── Helpers (set $REPLY; no subshell forks) ──────────────────────────────────
# Map an ascending integer onto the green→yellow→orange→red ladder. Thresholds
# are passed low→high; the 2>/dev/null lets a non-integer value fall through to
# green. Used by both the context bar (raw tokens) and the 5-hour limit (%).
grade_color() {  # value  t_yellow  t_orange  t_red
    if   [ "$1" -ge "$4" ] 2>/dev/null; then REPLY=$GRADE_RED
    elif [ "$1" -ge "$3" ] 2>/dev/null; then REPLY=$GRADE_ORANGE
    elif [ "$1" -ge "$2" ] 2>/dev/null; then REPLY=$GRADE_YELLOW
    else                                      REPLY=$GRADE_GREEN
    fi
}

# Format a token count compactly: 850 -> 850, 250000 -> 250k, 1000000 -> 1M.
fmt_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        local m=$(( n / 1000000 )) frac=$(( (n % 1000000) / 100000 ))
        [ "$frac" -eq 0 ] && REPLY="${m}M" || REPLY="${m}.${frac}M"
    elif [ "$n" -ge 1000 ]; then
        REPLY="$(( (n + 500) / 1000 ))k"
    else
        REPLY="$n"
    fi
}

# Visible length of a string that carries literal \033[...m SGR codes (used for
# right-align measurement). Strips the codes with parameter expansion only.
vlen() {
    local s=$1 out=''
    while [[ $s == *'\033['* ]]; do
        out+=${s%%'\033['*}      # text before the next ESC[
        s=${s#*'\033['}          # drop up to and including ESC[
        s=${s#*m}                # drop the SGR params and closing m
    done
    out+=$s
    REPLY=${#out}
}

# ── Field extraction (single jq pass → tab-separated) ────────────────────────
# used_tokens prefers context_window.total_input_tokens (current context, input
# + cache, matches used_percentage); falls back to summing current_usage for
# older payloads. context_window_size is 1000000 on extended-context models.
IFS=$'\t' read -r model cwd window used_tokens five_pct five_resets < <(
    echo "$input" | jq -r '
        [ (.model.display_name // ""),
          (.workspace.current_dir // .cwd // ""),
          (.context_window.context_window_size // 200000),
          (.context_window.total_input_tokens
             // ((.context_window.current_usage.input_tokens // 0)
                + (.context_window.current_usage.cache_read_input_tokens // 0)
                + (.context_window.current_usage.cache_creation_input_tokens // 0))),
          (.rate_limits.five_hour.used_percentage // ""),
          (.rate_limits.five_hour.resets_at // "")
        ] | @tsv')

# Sanitise integers used in arithmetic.
case "$window"      in ''|*[!0-9]*) window=200000 ;; esac
case "$used_tokens" in ''|*[!0-9]*) used_tokens=0 ;; esac
[ "$window" -le 0 ] 2>/dev/null && window=200000

# ── Git context ──────────────────────────────────────────────────────────────
git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
git_branch=""
[ -n "$git_root" ] && git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Line-2 path: repo-anchored inside a git tree, else full path with ~ for $HOME.
#   /Users/kady/dotfiles/claude  (repo /Users/kady/dotfiles)  -> dotfiles/claude
#   /Users/kady/dotfiles                                       -> dotfiles
#   /Users/kady/Downloads/x      (no repo)                     -> ~/Downloads/x
if [ -n "$git_root" ]; then
    repo_name=${git_root##*/}
    rel=${cwd#"$git_root"}; rel=${rel#/}
    [ -n "$rel" ] && cwd_display="${repo_name}/${rel}" || cwd_display="$repo_name"
else
    case "$cwd" in
        "$HOME")   cwd_display='~' ;;
        "$HOME"/*) cwd_display="~${cwd#"$HOME"}" ;;
        *)         cwd_display="$cwd" ;;
    esac
fi

# ── Context bar ──────────────────────────────────────────────────────────────
# Fill length is proportional to window usage; colour is graded by raw tokens.
pct_int=$(( used_tokens * 100 / window ))
filled=$(( (used_tokens * BAR_WIDTH + window / 2) / window ))
[ "$filled" -lt 0 ] && filled=0
[ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH

grade_color "$used_tokens" 100000 150000 200000; grade=$REPLY

# Build the bar fork-free: pad N spaces, then swap each space for the cell glyph.
printf -v bar_fill  '%*s' "$filled"                   ''
printf -v bar_empty '%*s' "$(( BAR_WIDTH - filled ))" ''
bar_fill=${bar_fill// /"$BAR_FILL"}
bar_empty=${bar_empty// /"$BAR_EMPTY"}

fmt_tokens "$used_tokens"; used_fmt=$REPLY
fmt_tokens "$window";      win_fmt=$REPLY
bar_segment="${C_GREY}Context: [${C_RESET}${grade}${bar_fill}${C_RESET}${C_EMPTY}${bar_empty}${C_RESET}${C_GREY}] ${C_RESET}${C_DIM}${used_fmt}/${win_fmt} ${C_RESET}${grade}(${pct_int}%)${C_RESET}"

# ── 5-hour rate-limit segment (kept verbatim — right-aligned on line 1) ───────
# Time remaining in the 5-hour window, "Xh Ym", blank once the window resets.
five_hour_remaining=""
if [ -n "$five_resets" ]; then
    now=$(date +%s)
    rem=$(( five_resets - now ))
    if [ "$rem" -gt 0 ] 2>/dev/null; then
        five_hour_remaining="$(( rem / 3600 ))h $(( (rem % 3600) / 60 ))m"
    fi
fi

five_hour_rendered=""
if [ -n "$five_pct" ]; then
    grade_color "${five_pct%%.*}" 50 75 90; five_color=$REPLY   # grade by truncated %
    printf -v five_disp '%.0f' "$five_pct"                      # display rounded %
    if [ -n "$five_hour_remaining" ]; then
        five_hour_rendered="${five_color}limit:(${five_disp}%${C_RESET}${C_DIM} - ${five_hour_remaining} remaining)${C_RESET}"
    else
        five_hour_rendered="${five_color}limit:${five_disp}%${C_RESET}"
    fi
fi

# ── Assemble line 1: MODEL │ branch │ bar  ……  limit (right-aligned) ─────────
left1="${C_MODEL}${model}${C_RESET}"
[ -n "$git_branch" ] && left1="${left1}${sep}${C_BRANCH}${BRANCH_GLYPH} ${git_branch}${C_RESET}"
left1="${left1}${sep}${bar_segment}"

right1="$five_hour_rendered"

# Right-align the limit segment using the terminal width (queried via /dev/tty,
# since stdout is not a TTY here). Falls back to a single space when unknown.
pad=" "
if [ -n "$right1" ]; then
    width=$( { tput cols < /dev/tty; } 2>/dev/null )
    [ -z "$width" ] && width=$( { stty size < /dev/tty; } 2>/dev/null | awk '{print $2}')
    [ -z "$width" ] && width=${COLUMNS:-0}
    vlen "$left1"; lv=$REPLY
    vlen "$right1"; rv=$REPLY
    if [ "$width" -gt 0 ] 2>/dev/null; then
        padding=$(( width - MARGIN - lv - rv ))
        [ "$padding" -ge 1 ] && printf -v pad '%*s' "$padding" ''
    fi
fi

# ── Emit (line 1 + newline + line 2, no trailing newline) ────────────────────
if [ -n "$right1" ]; then
    printf '%b%s%b\n' "$left1" "$pad" "$right1"
else
    printf '%b\n' "$left1"
fi
printf '%b' "${C_CWD}${cwd_display}${C_RESET}"

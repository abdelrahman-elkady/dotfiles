#!/usr/bin/env bash
# Claude Code status line — two-line, Starship-flavoured.
#
#   line 1:  MODEL effort │ Context: [████▒▒▒▒▒▒] 250k/1M (25%)    Limit: [█████▒▒▒▒▒] N% · Xh Ym left
#   line 2:  repo-anchored cwd  │  branch ⑂ worktree   (cwd is full path with ~ when outside a git repo)
#
# Both gauges share one render_bar widget. The context bar's fill tracks the % of
# the window used, coloured by the RAW used-token count (100k/150k/200k thresholds).
# The right-aligned 5-hour Limit bar's fill+colour track the quota % (50/75/90),
# followed by the exact % and the time until reset; the "Xh Ym left" tail drops
# once the window has reset.
#
# This runs on every render, so the helpers below set $REPLY (or use `printf -v`)
# instead of printing — call sites avoid a $()-subshell fork on the hot path.
input=$(</dev/stdin)

# ── Tunables ────────────────────────────────────────────────────────────────
BAR_WIDTH=20          # cells in the context bar
BAR_FILL='█'          # filled cell  (U+2588)
BAR_EMPTY='▒'         # empty cell   (U+2592)
BRANCH_GLYPH=$'\xee\x82\xa0'  # U+E0A0 powerline branch — byte-encoded so this PUA glyph survives editors; rendered via the PowerlineSymbols font
WT_GLYPH='⑂'          # U+2442 fork — marks a linked git worktree (swap for a nerd-font worktree icon if you prefer)
MARGIN=4              # right-align safety margin (Claude's render area < raw cols)

# ── Colours (literal \033 — expanded with %b at print time) ──────────────────
C_RESET='\033[00m'
C_MODEL='\033[01;33m'        # yellow bold
C_BRANCH='\033[31m'          # red
C_WORKTREE='\033[38;5;37m'   # teal — linked-worktree name beside the branch
C_CWD='\033[01;34m'          # blue bold
C_GREY='\033[38;5;245m'      # separators / labels
C_DIM='\033[02;37m'          # dim grey numerals
C_EMPTY='\033[38;5;240m'     # unfilled bar cells
GRADE_GREEN='\033[01;32m'
GRADE_YELLOW='\033[01;33m'
GRADE_ORANGE='\033[1;38;5;208m'
GRADE_RED='\033[01;31m'
GRADE_MAX='\033[01;38;5;201m'   # hot magenta — one tier above red, for effort:max

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

# Map the reasoning-effort tier onto its own hot ladder: the higher the effort,
# the hotter the colour, with `max` sitting one step above red on bright magenta.
# Anything unrecognised (or an unsupported-model empty string) falls to grey.
effort_color() {  # level
    case "$1" in
        low)    REPLY=$GRADE_GREEN  ;;
        medium) REPLY=$GRADE_YELLOW ;;
        high)   REPLY=$GRADE_ORANGE ;;
        xhigh)  REPLY=$GRADE_RED    ;;
        max)    REPLY=$GRADE_MAX    ;;
        *)      REPLY=$C_GREY       ;;
    esac
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

# Render a BAR_WIDTH-cell gauge "[████▒▒▒▒]" — `filled` graded cells coloured by
# $2, the rest dim, brackets grey. Sets $REPLY. Fork-free (printf -v + glyph
# swap). Shared by the context and 5-hour limit segments so both look identical.
render_bar() {  # filled  grade-colour
    local filled=$1 grade=$2 fill empty
    [ "$filled" -lt 0 ] && filled=0
    [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    printf -v fill  '%*s' "$filled"                   ''
    printf -v empty '%*s' "$(( BAR_WIDTH - filled ))" ''
    fill=${fill// /"$BAR_FILL"}
    empty=${empty// /"$BAR_EMPTY"}
    REPLY="${C_GREY}[${C_RESET}${grade}${fill}${C_RESET}${C_EMPTY}${empty}${C_RESET}${C_GREY}]${C_RESET}"
}

# Format a duration (seconds) compactly: 8580 -> "2h 23m", 2580 -> "43m",
# 7200 -> "2h". Drops any zero unit. Sets $REPLY.
fmt_remaining() {
    local h=$(( $1 / 3600 )) m=$(( ($1 % 3600) / 60 ))
    if   [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then REPLY="${h}h ${m}m"
    elif [ "$h" -gt 0 ];                   then REPLY="${h}h"
    else                                        REPLY="${m}m"
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
IFS=$'\t' read -r model effort worktree cwd window used_tokens five_pct five_resets < <(
    echo "$input" | jq -r '
        [ (.model.display_name // ""),
          (.effort.level // "none"),
          (.workspace.git_worktree // "none"),
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

# effort and worktree are *middle* TSV columns, so an empty value would be a bare
# consecutive tab — and since tab is IFS whitespace, `read` would collapse it and
# shift every later field. jq therefore emits the sentinel "none" for an absent
# effort (unsupported model) or worktree (main working tree); map them back to
# empty here so the render simply omits each segment.
[ "$effort"   = none ] && effort=""
[ "$worktree" = none ] && worktree=""

# ── Git context ──────────────────────────────────────────────────────────────
# One rev-parse yields the current toplevel (for the relative subpath below) plus
# the common git-dir. Inside a linked worktree the common-dir is the *main* repo's
# .git and comes back absolute, so its parent gives the repo name — letting line 2
# anchor to the repo, not the worktree's own directory.
git_root="" git_common=""
{ read -r git_root; read -r git_common; } < <(
    git -C "$cwd" --no-optional-locks rev-parse --show-toplevel --git-common-dir 2>/dev/null)
git_branch=""
[ -n "$git_root" ] && git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Line-2 path: repo-anchored inside a git tree, else full path with ~ for $HOME.
#   /Users/kady/dotfiles/claude     (repo /Users/kady/dotfiles)  -> dotfiles/claude
#   /Users/kady/dotfiles                                          -> dotfiles
#   /Users/kady/dotfiles-wt/claude  (worktree of dotfiles)       -> dotfiles/claude
#   /Users/kady/Downloads/x         (no repo)                    -> ~/Downloads/x
if [ -n "$git_root" ]; then
    # Repo name = parent of the common .git when it resolved absolutely (worktree
    # case); else the toplevel basename (main tree — common-dir comes back relative
    # there, and git_root is already the repo root).
    case "$git_common" in
        /*) repo_name=${git_common%/*}; repo_name=${repo_name##*/} ;;
        *)  repo_name=${git_root##*/} ;;
    esac
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

grade_color "$used_tokens" 100000 150000 200000; grade=$REPLY
render_bar "$filled" "$grade"; bar=$REPLY

fmt_tokens "$used_tokens"; used_fmt=$REPLY
fmt_tokens "$window";      win_fmt=$REPLY
bar_segment="${C_GREY}Context: ${C_RESET}${bar} ${C_DIM}${used_fmt}/${win_fmt} ${C_RESET}${grade}(${pct_int}%)${C_RESET}"

# ── 5-hour rate-limit segment (right-aligned on line 1) ───────────────────────
# Reuses render_bar: fill+colour track the quota %, graded at 50/75/90. Reads
# "Limit: [██▒▒…] 47% · 2h 13m left"; the "Xh Ym left" tail is dropped once
# the window has reset (no time remaining).
five_hour_remaining=""
if [ -n "$five_resets" ]; then
    rem=$(( five_resets - $(date +%s) ))
    [ "$rem" -gt 0 ] 2>/dev/null && { fmt_remaining "$rem"; five_hour_remaining=$REPLY; }
fi

five_hour_rendered=""
if [ -n "$five_pct" ]; then
    five_int=${five_pct%%.*}
    grade_color "$five_int" 50 75 90; five_color=$REPLY                       # grade by truncated %
    render_bar "$(( (five_int * BAR_WIDTH + 50) / 100 ))" "$five_color"       # round % to a cell count
    limit_bar=$REPLY
    printf -v five_disp '%.0f' "$five_pct"                                    # display rounded %
    five_hour_rendered="${C_GREY}Limit: ${C_RESET}${limit_bar} ${five_color}${five_disp}%${C_RESET}"
    [ -n "$five_hour_remaining" ] && five_hour_rendered+="${C_DIM} · ${five_hour_remaining} left${C_RESET}"
fi

# ── Assemble line 1: MODEL effort │ bar  ……  limit (right-aligned) ───────────
# Effort tier is an inline suffix on the model name, coloured by its own hot
# ladder. Absent (empty) on models that don't expose the effort parameter.
left1="${C_MODEL}${model}${C_RESET}"
if [ -n "$effort" ]; then
    effort_color "$effort"; left1="${left1} ${REPLY}${effort}${C_RESET}"
fi
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
line2="${C_CWD}${cwd_display}${C_RESET}"
[ -n "$git_branch" ] && line2="${line2}${sep}${C_BRANCH}${BRANCH_GLYPH} ${git_branch}${C_RESET}"
# Worktree follows the branch (grouped, no extra divider) when the cwd is inside a
# linked git worktree; starts its own segment if there's no branch (detached HEAD).
if [ -n "$worktree" ]; then
    [ -n "$git_branch" ] && wt_lead=" " || wt_lead="$sep"
    line2="${line2}${wt_lead}${C_WORKTREE}${WT_GLYPH} ${worktree}${C_RESET}"
fi
printf '%b' "$line2"

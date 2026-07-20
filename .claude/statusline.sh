#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // empty')

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
DIM='\033[2m'
RESET='\033[0m'

PROJECT="${DIR##*/}"
GIT_INFO=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  REMOTE=$(git -C "$DIR" remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')
  [ -n "$REMOTE" ] && PROJECT="$REMOTE"
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
  STATUS=$(git -C "$DIR" diff --name-status HEAD 2>/dev/null)
  ADDED=$(echo "$STATUS" | grep -c '^A' | tr -d ' ')
  MODIFIED=$(echo "$STATUS" | grep -c '^M' | tr -d ' ')
  DELETED=$(echo "$STATUS" | grep -c '^D' | tr -d ' ')
  RENAMED=$(echo "$STATUS" | grep -c '^R' | tr -d ' ')

  GIT_INFO=" ${DIM}on${RESET} ${CYAN}${BRANCH}${RESET}"
  [ "$ADDED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${GREEN}+${ADDED}${RESET}"
  [ "$MODIFIED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${YELLOW}~${MODIFIED}${RESET}"
  [ "$DELETED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${RED}-${DELETED}${RESET}"
  [ "$RENAMED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${MAGENTA}->${RENAMED}${RESET}"
fi

if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

printf '%b\n' "${DIM}[${MODEL}]${RESET} ${PROJECT}${GIT_INFO} ${DIM}|${RESET} ${BAR_COLOR}${PCT}%${RESET}"

# Delegate to project-local statusline script if present (avoid self-recursion)
if [ -n "$PROJECT_DIR" ]; then
  LOCAL_SCRIPT="${PROJECT_DIR}/.claude/statusline.sh"
  SELF_REAL=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
  LOCAL_REAL=$(readlink -f "$LOCAL_SCRIPT" 2>/dev/null || echo "$LOCAL_SCRIPT")
  if [ -x "$LOCAL_SCRIPT" ] && [ "$LOCAL_REAL" != "$SELF_REAL" ]; then
    PROJECT_LINE=$(echo "$input" | "$LOCAL_SCRIPT" 2>/dev/null)
    [ -n "$PROJECT_LINE" ] && printf '%b\n' "$PROJECT_LINE"
  fi
fi

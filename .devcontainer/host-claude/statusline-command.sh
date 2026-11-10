#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Use only the basename of cwd
dir_name=$(basename "$cwd")

# Get git branch if inside a git repository
git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$git_branch" = "HEAD" ]; then
  git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build status parts
if [ -n "$git_branch" ]; then
  parts="$dir_name ($git_branch)"
else
  parts="$dir_name"
fi

if [ -n "$model" ]; then
  parts="$parts | $model"
fi

if [ -n "$used" ]; then
  parts="$parts | ctx: $(printf '%.0f' "$used")%"
fi

# Rate limit information
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Format remaining time as "Xh Ym" or "Ym"
format_remaining() {
  resets_at="$1"
  now=$(date +%s)
  diff=$(( resets_at - now ))
  if [ "$diff" -le 0 ]; then
    echo "now"
  else
    hours=$(( diff / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    if [ "$hours" -gt 0 ]; then
      echo "${hours}h${mins}m"
    else
      echo "${mins}m"
    fi
  fi
}

rl_parts=""

if [ -n "$five_used" ] && [ -n "$five_resets" ]; then
  five_pct=$(printf '%.0f' "$five_used")
  five_rem=$(format_remaining "$five_resets")
  rl_parts="${five_pct}%(${five_rem})"
fi

if [ -n "$week_used" ] && [ -n "$week_resets" ]; then
  week_pct=$(printf '%.0f' "$week_used")
  week_rem=$(format_remaining "$week_resets")
  case "$rl_parts" in
    "") rl_parts="7d:${week_pct}%(${week_rem})" ;;
    *)  rl_parts="${rl_parts} 7d:${week_pct}%(${week_rem})" ;;
  esac
fi

if [ -n "$rl_parts" ]; then
  parts="$parts | rl: $rl_parts"
fi

printf '%s' "$parts"

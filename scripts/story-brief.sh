#!/usr/bin/env bash
# Extract one story's full text from a plan file into a brief file, so
# multi-story dispatches hand the implementer a path instead of pasting
# story text through the host's context.
#
# Usage: story-brief.sh PLAN_FILE STORY_NUMBER [OUTFILE]
# Default OUTFILE: <repo-root>/.ship/scratch/story-<N>-brief.md
#
# Matches the heading formats /ship:dev normalizes: "## Story N",
# "### Task N", "## N. Title" (any heading level). If no heading matches,
# exits 3 — the host falls back to writing the brief file itself.

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "usage: story-brief.sh PLAN_FILE STORY_NUMBER [OUTFILE]" >&2
  exit 2
fi

plan=$1
n=$2
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }
case "$n" in (*[!0-9]*|'') echo "STORY_NUMBER must be a positive integer" >&2; exit 2;; esac

if [ $# -eq 3 ]; then
  out=$3
else
  root=$(git rev-parse --show-toplevel)
  dir="$root/.ship/scratch"
  mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  out="$dir/story-${n}-brief.md"
fi

awk -v n="$n" '
  /^```/ { infence = !infence }
  !infence && /^#+[ \t]+((Story|Task)[ \t]+[0-9]+|[0-9]+\.[ \t])/ {
    intask = ($0 ~ ("^#+[ \t]+((Story|Task)[ \t]+" n "([^0-9]|$)|" n "\\.[ \t])"))
  }
  intask { print }
' "$plan" > "$out"

if [ ! -s "$out" ]; then
  rm -f "$out"
  echo "story ${n} not found in ${plan} (no heading matching Story/Task ${n})" >&2
  exit 3
fi

echo "wrote ${out}: $(wc -l < "$out" | tr -d ' ') lines"

#!/usr/bin/env bash
# Generate a review package: commit list, stat summary, and full diffs
# with extended context, written to one file the reviewer reads in a
# single call. The package never enters the host's context.
#
# Usage:
#   review-package.sh BASE HEAD [OUTFILE]
#     Range mode — single-story waves. BASE is the commit recorded
#     before the story's implementation started — never HEAD~1, which
#     silently drops all but the last commit of a multi-commit story.
#
#   review-package.sh --commits SHA[,SHA...] [OUTFILE]
#     Commit mode — multi-story parallel waves, where stories interleave
#     commits on the same branch and a range would mix stories. Pass
#     exactly the SHAs the story's implementer reported.
#
# Default OUTFILE: <repo-root>/.ship/scratch/review-<id>.diff

set -euo pipefail

usage() {
  echo "usage: review-package.sh BASE HEAD [OUTFILE]" >&2
  echo "       review-package.sh --commits SHA[,SHA...] [OUTFILE]" >&2
  exit 2
}

default_out() {
  local id=$1 root dir
  root=$(git rev-parse --show-toplevel)
  dir="$root/.ship/scratch"
  mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  echo "$dir/review-${id}.diff"
}

[ $# -ge 2 ] || usage

if [ "$1" = "--commits" ]; then
  [ $# -le 3 ] || usage
  IFS=',' read -r -a shas <<< "$2"
  [ "${#shas[@]}" -ge 1 ] || usage
  for sha in "${shas[@]}"; do
    git rev-parse --verify --quiet "${sha}^{commit}" >/dev/null || { echo "bad commit: $sha" >&2; exit 2; }
  done
  if [ $# -eq 3 ]; then
    out=$3
  else
    first=$(git rev-parse --short "${shas[0]}")
    last=$(git rev-parse --short "${shas[${#shas[@]}-1]}")
    out=$(default_out "${first}..${last}-picked")
  fi
  {
    echo "# Review package: ${#shas[@]} commit(s) (picked)"
    echo
    echo "## Commits"
    for sha in "${shas[@]}"; do git log --oneline -1 "$sha"; done
    echo
    echo "## Files changed"
    for sha in "${shas[@]}"; do git show --stat --format="" "$sha"; done
    echo
    echo "## Diff"
    for sha in "${shas[@]}"; do git show -U10 --format="commit %h %s" "$sha"; echo; done
  } > "$out"
  echo "wrote ${out}: ${#shas[@]} commit(s), $(wc -c < "$out" | tr -d ' ') bytes"
else
  [ $# -le 3 ] || usage
  base=$1
  head=$2
  git rev-parse --verify --quiet "$base" >/dev/null || { echo "bad BASE: $base" >&2; exit 2; }
  git rev-parse --verify --quiet "$head" >/dev/null || { echo "bad HEAD: $head" >&2; exit 2; }
  if [ $# -eq 3 ]; then
    out=$3
  else
    out=$(default_out "$(git rev-parse --short "$base")..$(git rev-parse --short "$head")")
  fi
  {
    echo "# Review package: ${base}..${head}"
    echo
    echo "## Commits"
    git log --oneline "${base}..${head}"
    echo
    echo "## Files changed"
    git diff --stat "${base}..${head}"
    echo
    echo "## Diff"
    git diff -U10 "${base}..${head}"
  } > "$out"
  commits=$(git rev-list --count "${base}..${head}")
  echo "wrote ${out}: ${commits} commit(s), $(wc -c < "$out" | tr -d ' ') bytes"
fi

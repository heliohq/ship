#!/bin/bash
set -eu

REPO=""

cleanup() {
  if [ -n "$REPO" ]; then
    rm -rf "$REPO"
  fi
}

main() {
  local repo_root
  local setup_script
  repo_root=$(cd "$(dirname "$0")/.." && pwd)
  setup_script=${SETUP_SCRIPT:-"$repo_root/bin/setup-ship-coding.sh"}
  REPO=$(mktemp -d)
  trap cleanup EXIT

  git init "$REPO" >/dev/null 2>&1
  printf '.ship/\n' > "$REPO/.gitignore"

  (
    cd "$REPO"
    bash "$setup_script" "gitignore migration test" "$REPO" >/dev/null
  )

  if grep -qxF '.ship/' "$REPO/.gitignore"; then
    echo "expected .ship/ to be removed from .gitignore" >&2
    exit 1
  fi

  for entry in ".ship/tasks/" ".ship/audit/"; do
    if ! grep -qxF "$entry" "$REPO/.gitignore"; then
      echo "missing $entry in .gitignore" >&2
      exit 1
    fi
  done

  mkdir -p "$REPO/.ship/rules"
  : > "$REPO/.ship/rules/example.sh"

  if git -C "$REPO" check-ignore -q .ship/rules/example.sh; then
    echo "expected .ship/rules/ to remain trackable" >&2
    exit 1
  fi
}

main "$@"

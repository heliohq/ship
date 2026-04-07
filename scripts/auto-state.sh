#!/usr/bin/env bash
set -u

STATE_FILE="${SHIP_AUTO_STATE_FILE:-.ship/ship-auto.local.md}"
COMMAND="${1:-}"
KEY="${2:-}"
VALUE="${3:-}"

usage() {
  cat <<'EOF' >&2
Usage:
  scripts/auto-state.sh get <key>
  scripts/auto-state.sh set <key> <value>
  scripts/auto-state.sh bump <key>
EOF
  exit 1
}

require_state_file() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "Ship auto state file not found: $STATE_FILE" >&2
    exit 1
  fi
}

frontmatter_value() {
  local key="$1"

  sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
    | grep "^${key}:" \
    | head -1 \
    | sed "s/^${key}: *//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | tr -d '\r' || true
}

set_frontmatter_value() {
  local key="$1" value="$2" tmp_file
  tmp_file=$(mktemp)

  awk -v key="$key" -v value="$value" '
    BEGIN {
      in_frontmatter = 0
      replaced = 0
    }

    NR == 1 && $0 == "---" {
      in_frontmatter = 1
      print
      next
    }

    in_frontmatter && $0 == "---" {
      if (!replaced) {
        print key ": " value
      }
      in_frontmatter = 0
      print
      next
    }

    in_frontmatter {
      if ($0 ~ ("^" key ":")) {
        print key ": " value
        replaced = 1
        next
      }
    }

    {
      print
    }
  ' "$STATE_FILE" > "$tmp_file"

  mv "$tmp_file" "$STATE_FILE"
  printf '%s\n' "$value"
}

require_state_file

case "$COMMAND" in
  get)
    [ -n "$KEY" ] || usage
    frontmatter_value "$KEY"
    ;;
  set)
    [ -n "$KEY" ] && [ -n "$VALUE" ] || usage
    set_frontmatter_value "$KEY" "$VALUE"
    ;;
  bump)
    [ -n "$KEY" ] || usage
    CURRENT_VALUE=$(frontmatter_value "$KEY")
    if [ -z "$CURRENT_VALUE" ]; then
      CURRENT_VALUE=0
    fi
    NEXT_VALUE=$((CURRENT_VALUE + 1))
    set_frontmatter_value "$KEY" "$NEXT_VALUE"
    ;;
  *)
    usage
    ;;
esac

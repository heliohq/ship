#!/usr/bin/env bash
# Ship plugin - minimal SessionStart hint.
#
# Keep this hook deliberately small. It should only remind the host agent to
# consult /ship:use-ship for Ship routing. Do not inject docs indexes, design
# pointers, memory, or production artifact content here.

set -u

# Drain stdin so hook callers can always pipe their JSON payload here.
INPUT=$(cat || true)
: "$INPUT"

PARTS="<SHIP_ROUTING>
Ship is available in this repo. At the beginning of the session, consult /ship:use-ship when the user's request may need Ship process.
- If the user names a specific /ship:* command, follow that command directly.
- If the request is unrelated to software delivery, do not use Ship.
- Do not start /ship:auto unless the user explicitly asks for full end-to-end delivery.
</SHIP_ROUTING>"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  jq -n --arg context "$PARTS" '{additional_context: $context}'
else
  jq -n --arg context "$PARTS" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $context
    }
  }'
fi

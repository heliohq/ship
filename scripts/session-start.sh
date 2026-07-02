#!/usr/bin/env bash
# Ship plugin - minimal SessionStart hint.
#
# Keep this hook deliberately small. It should only remind the host agent to
# consult /ship:use-ship for Ship routing. Do not inject docs indexes, design
# pointers, memory, or production artifact content here.
#
# The payload is static, so the JSON is emitted verbatim — no jq dependency
# (a missing jq used to silently swallow the hint).

set -u

# Drain stdin so hook callers can always pipe their JSON payload here.
INPUT=$(cat || true)
: "$INPUT"

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<SHIP_ROUTING>\nShip is available in this repo. At the beginning of the session, consult /ship:use-ship when the user's request may need Ship process.\n- If the user names a specific /ship:* command, follow that command directly.\n- If the request is unrelated to software delivery, do not use Ship.\n- Do not start /ship:auto unless the user explicitly asks for full end-to-end delivery.\n</SHIP_ROUTING>"
  }
}
EOF

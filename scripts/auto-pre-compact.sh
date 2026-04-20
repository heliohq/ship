#!/usr/bin/env bash
# PreCompact hook for ship:auto.
#
# Why this exists: post-compact, the agent loses the fine-grained signal
# that the user cancelled a ship-auto task (via Ctrl-C and then moving on
# to unrelated work). Without this hook, the rehydrated agent sees the
# state file and resumes the cancelled task, which is never what the user
# wants.
#
# What this does: before compact strips the evidence, scan the pre-compact
# transcript for a cancellation pattern — a turn interrupt followed by
# user messages that do NOT reference ship/continue/resume. If found,
# archive the state file so post-compact auto sees a clean slate.
#
# False positive bias: the pattern requires BOTH an interrupt marker AND
# no subsequent ship re-engagement. Normal mid-task compact (no interrupt)
# leaves state untouched.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_FILE="${REPO_ROOT}/.ship/ship-auto.local.md"

# Nothing to do if no active task
[ -f "$STATE_FILE" ] || exit 0

# Read hook input from stdin — PreCompact delivers a JSON payload with
# transcript_path among other fields.
HOOK_INPUT=$(cat)

# Extract transcript_path. If python3 isn't available, bail quietly —
# this hook is best-effort, not a hard gate.
command -v python3 >/dev/null 2>&1 || exit 0

TRANSCRIPT_PATH=$(
  printf '%s' "$HOOK_INPUT" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' \
      2>/dev/null
)
[ -f "$TRANSCRIPT_PATH" ] || exit 0

# Analyze transcript for cancellation pattern.
VERDICT=$(
  python3 - "$TRANSCRIPT_PATH" <<'PY'
import json, re, sys

path = sys.argv[1]
messages = []
with open(path, 'r', errors='ignore') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            messages.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Find the latest interrupt marker.
interrupt_re = re.compile(
    r'(interrupted by user|request interrupted|tool use was rejected)',
    re.IGNORECASE,
)
interrupt_idx = None
for i, m in enumerate(messages):
    if interrupt_re.search(json.dumps(m)):
        interrupt_idx = i

# No interrupt => task is live, leave alone.
if interrupt_idx is None:
    print("live")
    sys.exit(0)

# After an interrupt, look at subsequent user messages. If ANY of them
# references ship/continue/resume, treat the task as live (user wants
# to continue). Otherwise, treat as cancelled.
ship_re = re.compile(
    r'\b(ship|continue|resume|keep going|/ship:)\b',
    re.IGNORECASE,
)
for m in messages[interrupt_idx + 1:]:
    role = m.get('role') or m.get('type') or ''
    if role != 'user':
        continue
    content = json.dumps(m.get('message', m.get('content', m)))
    if ship_re.search(content):
        print("live")
        sys.exit(0)

print("cancelled")
PY
)

if [ "$VERDICT" != "cancelled" ]; then
  exit 0
fi

# Archive the state file so post-compact init/resume sees no active task.
task_id=$(awk '/^task_id:/{print $2}' "$STATE_FILE" 2>/dev/null || echo "unknown")
archive_dir="${REPO_ROOT}/.ship/tasks/${task_id}"
mkdir -p "$archive_dir"

{
  echo "# cancelled_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "# reason: user abandoned task — interrupt followed by unrelated prompts detected pre-compact"
  echo ""
  cat "$STATE_FILE"
} > "$archive_dir/ship-auto.cancelled.md"

rm -f "$STATE_FILE"
exit 0

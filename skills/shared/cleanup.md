# Cleanup Contract (shared)

Any skill that calls `shared/startup.md` must also follow this contract.
Cleanup is **mandatory** — run it on success, failure, timeout, exception,
or interrupt. Leaked services, containers, or ports poison the next run.

Input: the same `EVIDENCE_DIR` startup used — cleanup reads
`$EVIDENCE_DIR/pids.txt` to know what to kill.

## The contract

1. **Kill every tracked PID** — SIGTERM, then SIGKILL if it survives.
2. **Stop every container this run started** — `docker compose stop`.
   Never `down -v`: that wipes volumes and breaks the next run.
3. **Verify the ports are free** — a surviving child shows up in `lsof`;
   report it as a cleanup failure instead of leaking silently.
4. **Report one line per service** so the caller confirms nothing leaked.

## Implementation

Wire it to a trap so it runs even on an abnormal exit (timeout, error):

```bash
cleanup() {
  local errors=0
  if [ -f "$EVIDENCE_DIR/pids.txt" ]; then
    while read -r pid; do
      [ -z "$pid" ] && continue
      kill -0 "$pid" 2>/dev/null || { echo "[Cleanup] PID $pid — already gone"; continue; }
      kill "$pid" 2>/dev/null
      for _ in 1 2 3; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null; echo "[Cleanup] PID $pid — force killed"
      else
        echo "[Cleanup] PID $pid — stopped"
      fi
    done < "$EVIDENCE_DIR/pids.txt"
  fi
  for f in compose.yml docker-compose.yml; do
    [ -f "$f" ] && docker compose -f "$f" ps -q 2>/dev/null | grep -q . \
      && { docker compose -f "$f" stop 2>&1 | tail -3; echo "[Cleanup] $f — stopped"; }
  done
  for port in ${CLEANUP_PORTS:-3000 8000 8080 4000 5173}; do
    lsof -i :"$port" -t >/dev/null 2>&1 \
      && { echo "[Cleanup] WARN port $port still in use"; errors=$((errors + 1)); }
  done
  [ "$errors" -eq 0 ] && echo "[Cleanup] done — all stopped, ports free" \
    || echo "[Cleanup] $errors port(s) still in use — investigate"
}
trap cleanup EXIT INT TERM
```

## Exceptions and scope

- **Keep services alive for debugging** is the only reason to skip cleanup,
  and only on the user's explicit instruction — still tell them what's
  running so they can stop it later.
- Cleanup only stops processes. It never touches **artifacts** in
  `$EVIDENCE_DIR` (they persist), **database state** (rollback is a
  per-skill decision), or **git state** (that's `/ship:handoff`'s job).

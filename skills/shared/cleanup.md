# Cleanup Contract (shared)

Any skill that calls `shared/startup.md` must also follow this contract.
Cleanup is **mandatory** — run it on success, on failure, on timeout, on
exception, on user interrupt. Leaking services, containers, or ports
poisons the next run and wastes the user's resources.

## Inputs from the calling skill

The same `EVIDENCE_DIR` that was used in startup — cleanup reads
`$EVIDENCE_DIR/pids.txt` to know what to kill.

```bash
EVIDENCE_DIR="<same value used in shared/startup.md>"
```

## The contract

Every skill that starts services must:

1. **Kill every PID it tracked.** Read `$EVIDENCE_DIR/pids.txt` and
   send SIGTERM, then SIGKILL if the process hasn't exited.
2. **Stop every container it started.** `docker compose stop` for any
   compose stack brought up during startup. Do not `down -v` — that
   wipes volumes and breaks the next run.
3. **Verify the ports it used are free.** If a child process survives,
   `lsof -i :<port>` will show it — report that as a cleanup failure
   rather than silently leaking.
4. **Report what was cleaned up.** One line per service, so the caller
   can confirm nothing leaked.

## Implementation

```bash
CLEANUP_ERRORS=0

# 1. Kill tracked PIDs
if [ -f "$EVIDENCE_DIR/pids.txt" ]; then
  while read -r pid; do
    [ -z "$pid" ] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      # Give it 3 seconds to shut down gracefully
      for i in 1 2 3; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
      done
      # Still alive? Force kill.
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null
        echo "[Cleanup] PID $pid — force killed"
      else
        echo "[Cleanup] PID $pid — stopped"
      fi
    else
      echo "[Cleanup] PID $pid — already gone"
    fi
  done < "$EVIDENCE_DIR/pids.txt"
fi

# 2. Stop docker compose (if used during startup)
for COMPOSE in compose.yml docker-compose.yml; do
  if [ -f "$COMPOSE" ]; then
    # Only stop if this run started something
    if docker compose -f "$COMPOSE" ps --services --filter status=running 2>/dev/null | grep -q .; then
      docker compose -f "$COMPOSE" stop 2>&1 | tail -3
      echo "[Cleanup] docker compose ($COMPOSE) — stopped"
    fi
  fi
done

# 3. Verify ports are free
# Reads the port that startup emitted (adjust PORTS list to match your skill)
for PORT in ${CLEANUP_PORTS:-3000 8000 8080 4000 5173}; do
  if lsof -i :"$PORT" -t >/dev/null 2>&1; then
    echo "[Cleanup] WARN port $PORT still in use by $(lsof -i :$PORT -t | tr '\n' ',')"
    CLEANUP_ERRORS=$((CLEANUP_ERRORS + 1))
  fi
done

# 4. Report summary
if [ "$CLEANUP_ERRORS" -eq 0 ]; then
  echo "[Cleanup] done — all services stopped, all ports free"
else
  echo "[Cleanup] $CLEANUP_ERRORS port(s) still in use — investigate manually"
fi
```

## When NOT to clean up

Only one case: **the user asked to keep services running for debugging.**
In that case, the skill's explicit instruction overrides the contract —
but the skill must still tell the user what's still running so they can
stop it manually later.

## Trap patterns

For skills that might exit abnormally (test timeout, error mid-run), wire
cleanup to a shell trap so it runs no matter what:

```bash
cleanup() {
  # (the block above)
}
trap cleanup EXIT INT TERM
```

## What this does NOT cover

- **Artifacts** — screenshots, videos, reports, test output. These belong
  in `$EVIDENCE_DIR` and should persist after cleanup. Cleanup only stops
  processes; it does not touch files.
- **Database state** — if the skill seeded data, it stays in the database
  unless the skill explicitly decided to roll back. That's a per-skill
  policy decision, not a cleanup concern.
- **Git state** — cleanup never touches the working tree, the index, or
  branches. That's `/ship:handoff`'s job.

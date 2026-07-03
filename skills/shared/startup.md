# Application Startup (shared)

Discover, start, and verify any app before a skill interacts with it — QA,
E2E, or anything exercising the real service. Probe the project and act on
what you find; assume no specific stack. You know how to start apps — this
reference only fixes the contract: where logs and PIDs go, what "ready"
means, and what to do when startup fails.

## Inputs from the calling skill

The calling skill must set one environment variable first:

```bash
EVIDENCE_DIR="<path where this phase writes logs, pids, and evidence>"
# QA:  EVIDENCE_DIR=".ship/tasks/$TASK_ID/qa"
# E2E: EVIDENCE_DIR=".ship/tasks/$TASK_ID/e2e"
mkdir -p "$EVIDENCE_DIR"
```

All logs and PID tracking go under `$EVIDENCE_DIR`. Cleanup belongs to the
calling skill (see `cleanup.md`) — **startup only starts, it never stops.**

## Workflow

```
1. Discover    Probe project files to detect stack, commands, ports, deps
2. Install     Install dependencies with the detected package manager
3. Infra       Start infrastructure (docker, databases, caches)
4. Migrate     Run database migrations if a migration tool exists
5. Start       Launch the application, track PIDs
6. Verify      Poll until the app responds (readiness check)
```

## Phase 1: Discover

Answer five questions: runtime/framework? start command? port?
infrastructure dependencies? available testing tools?

Probe in this order and stop when you have clear answers — human-written
instructions outrank inference:

1. `CLAUDE.md` / `AGENTS.md` / README ("getting started", "development")
2. `Makefile` targets (`dev`, `start`, `serve`, `run`, `up`, `migrate`)
3. Package-manager manifests (`package.json` scripts, `pyproject.toml`,
   `go.mod`, `Cargo.toml`, `Gemfile`, `mix.exs`, …) — these also identify
   the runtime, the package manager (from the lockfile), and the framework
4. `docker-compose.yml` / `Dockerfile`, `.env` / `.env.example` (ports,
   DATABASE_URL, required env)

**Always prefer the start command found in discovery over a framework
default you infer.**

### Testing tools

`curl` is assumed. For browser testing, first check whether the harness
already exposes native browser automation (e.g. Chrome MCP or preview
tools in Claude Code) — if so, use that and skip the agent-browser
check entirely. Electron testing always needs the `agent-browser` CLI
(via CDP), and browser testing needs it only when no native tooling is
available. If it's needed and `which agent-browser` fails, AskUserQuestion:

> Browser testing requires agent-browser (https://github.com/vercel-labs/agent-browser).
> A) Install it now (`npm install -g agent-browser`)  B) Skip browser testing this run

On A, install and re-verify (continue without it if the install fails).
On B, skip `references/browser.md` and `references/electron.md` — API and
CLI testing still run with curl.

In a dispatched or no-questions run (subagents cannot reach the user):
don't ask — choose A automatically; if the install fails, degrade to
curl-only checks and record the skipped browser coverage in the report.

## Phase 2: Install dependencies

Install with the package manager the lockfile names (pnpm/yarn/bun/npm,
poetry/uv/pipenv/pip, bundler, cargo, go mod). Don't switch managers.

## Phase 3: Infrastructure

If a compose file exists: `docker compose up -d`, then wait for services
to report healthy (poll `docker compose ps`, ~120s budget; fall back to a
TCP check on the service ports). If there is no compose file but `.env`
carries a database URL, assume an external database and skip this phase.

## Phase 4: Migrations and seed

If a migration tool is present, run it (prisma/drizzle/typeorm, django
`manage.py migrate`, alembic, rails `db:migrate`, goose/migrate/atlas,
`mix ecto.migrate` — or a Makefile `migrate` target). Seed if the project
ships seed data (`prisma db seed`, fixtures, `db:seed`, `make seed`).
No migration tool → skip.

## Phase 5: Start the application

The contract, per service:

```bash
PORT=<detected_port>
lsof -i :$PORT -t 2>/dev/null && echo "WARNING: port $PORT already in use" || echo "PORT $PORT: free"

nohup <start_command> > "$EVIDENCE_DIR/app.log" 2>&1 &
echo $! >> "$EVIDENCE_DIR/pids.txt"
```

**Every started process gets its PID appended to `pids.txt` in the same
command that starts it** — an untracked PID is a leaked process at
cleanup time. Monorepos with multiple services: one log file and one
`pids.txt` line per service (`frontend.log`, `backend.log`, …).

## Phase 6: Verify readiness

Poll up to 90 seconds across common health endpoints before declaring
success or failure:

```bash
for i in $(seq 1 30); do
  for ENDPOINT in "/" "/health" "/healthz" "/api/health" "/api"; do
    STATUS=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:$PORT$ENDPOINT" 2>/dev/null)
    [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 500 ] && echo "READY: $ENDPOINT → $STATUS" && break 2
  done
  sleep 3
done
```

On timeout: `tail -20 "$EVIDENCE_DIR/app.log"` and check the PID is alive
(`kill -0 $(tail -1 "$EVIDENCE_DIR/pids.txt")`). Report per service:

```
[Startup] app:3000 — healthy | FAILED (+ last 20 log lines when failed)
```

If a service fails, SKIP only the criteria that depend on it — not the
entire run, unless everything depends on it.

## Troubleshooting recognition list

- **Port in use** → `lsof -i :<port> -t`; kill only if it's a leftover from a previous run.
- **App starts then immediately dies** → tail the log; usual causes: missing `.env` (copy `.env.example`), database not ready (docker still starting / migrations not run), port conflict, missing build step.
- **500 on every request** → framework needs a build step (`next build`, `collectstatic`), or the app started before migrations ran.
- **Migrations fail** → is the DB reachable (TCP check)? is `DATABASE_URL` set? is `.env` missing while `.env.example` exists?
- **Install fails** → clear the package cache / recreate the venv, retry once.
- **Docker won't start** → `docker info` (daemon running?), `docker compose config --quiet` (file valid?). Ask before any `down -v` reset — it destroys volumes.

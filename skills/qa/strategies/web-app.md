# Web App QA Strategy

How to QA test a web application (React, Next.js, Vue, Angular, etc.).

## Project discovery

Check these files to discover how the app runs:

1. `CLAUDE.md` / `AGENTS.md` — run commands, ports
2. `Makefile` — `run-*`, `dev`, `start`, `serve` targets
3. `package.json` — `scripts.dev`, `scripts.start`
4. `docker-compose.yml` / `compose.yml`
5. `README.md` — "Getting Started" section
6. `.env.example` — port and URL config

## Service startup

### Docker dependencies (if applicable)

```bash
docker compose config --quiet 2>&1          # validate
docker compose images -q 2>/dev/null        # check images
docker compose build                        # build if missing (300s timeout)
docker compose up -d                        # start
```

Wait for health (120s): poll `docker compose ps --format json` for
"healthy" status, or TCP check on exposed ports.

### Database migrations (if applicable)

Look for migration commands in Makefile/README:
- `make migrate`, `make db-setup`
- `npx prisma migrate deploy`
- `python manage.py migrate`
- `rails db:migrate`

Run after docker deps healthy, before app startup.

### App service startup

All logs and PID tracking go to `.ship/tasks/<task_id>/qa/`.

```bash
QA_DIR=".ship/tasks/<task_id>/qa"

# Check port available
lsof -i :<port> -t 2>/dev/null && echo 'PORT_IN_USE' || echo 'PORT_FREE'

# Check dependencies installed
[ -d node_modules ] || npm install  # or pnpm install

# Start in background (PID tracking in same call)
nohup <start command> > "$QA_DIR/<service>.log" 2>&1 & \
  PID=$!; echo $PID >> "$QA_DIR/pids.txt"; \
  echo "Started <service> PID=$PID"

# Poll readiness (90s)
for i in $(seq 1 30); do
  curl -sf http://localhost:<port>/ > /dev/null 2>&1 && echo 'READY' && break
  sleep 3
done
```

## Chrome DevTools MCP workflow

Per-page test sequence:

```
1. Navigate:   mcp__chrome-devtools__navigate_page(url="http://localhost:<port>/<path>")
2. Wait:       mcp__chrome-devtools__wait_for(text=["<expected>"], timeout=10000)
3. Snapshot:   mcp__chrome-devtools__take_snapshot()
4. Console:    mcp__chrome-devtools__list_console_messages(types=["error"])
5. Network:    mcp__chrome-devtools__list_network_requests(resourceTypes=["xhr","fetch"])
6. Screenshot: mcp__chrome-devtools__take_screenshot(filePath="<qa_dir>/<test-name>.png")
```

### WebSocket verification (browser-side)

```
mcp__chrome-devtools__list_network_requests(resourceTypes=["websocket"])
```

### Lighthouse accessibility audit

When UI components changed:
```
mcp__chrome-devtools__lighthouse_audit(mode="snapshot", device="desktop")
```

### Performance trace

When first-paint-related code changed:
```
mcp__chrome-devtools__performance_start_trace(reload=true, autoStop=true)
```

- LCP <= 2.5s → good
- LCP 2.5-4.0s → warn
- LCP > 4.0s → likely regression

## Functional testing tools

| What to verify | Tool | Evidence |
|----------------|------|---------|
| Page renders | Browser screenshot | L1 |
| UI interaction | Browser click/fill + screenshot | L1 |
| Form submission | Browser fill_form + submit | L1 |
| Console errors | Browser console API | L1 |
| API responses | curl + parse body | L1 |
| Network requests | Browser network tab | L1 |
| Server liveness | curl health check | L2 |

## Exploratory focus areas

For web apps, prioritize:
1. Forms — empty submit, invalid input, double submit
2. Navigation — back/forward, deep links, refresh
3. Responsive — does it break on narrow viewport?
4. Loading states — what shows while data loads?
5. Error states — what shows when API fails?
6. Auth boundaries — logged out user accessing protected page?

## Cleanup (mandatory)

```bash
QA_DIR=".ship/tasks/<task_id>/qa"

# Kill app processes
if [ -f "$QA_DIR/pids.txt" ]; then
  while read PID; do kill $PID 2>/dev/null; done < "$QA_DIR/pids.txt"
  sleep 2
  while read PID; do kill -9 $PID 2>/dev/null; done < "$QA_DIR/pids.txt"
fi

# Stop docker
docker compose down --remove-orphans 2>/dev/null || true

# Verify ports free
for PORT in <ports>; do
  lsof -i :$PORT -t 2>/dev/null && echo "WARNING: port $PORT still in use"
done
```

# Smoke Testing

Basic "does it start and is it reachable?" checks. Run before any
functional or exploratory testing.

## What to check

1. **Service starts** — app process runs without crash
2. **Port listening** — expected port is open
3. **Health endpoint** — returns 200 (or TCP connect succeeds)
4. **Homepage loads** — returns non-error response

See `strategies/web-app.md` for exact startup and readiness commands.

## Common health endpoints

`/health`, `/healthz`, `/api/health`, `/`

## If smoke fails

```
[QA] <service> failed to start within 90 seconds.
[QA] Last 20 lines of server log:
<tail -20 .ship/tasks/<task_id>/qa/<service>.log>
```

SKIP all criteria that depend on this service. Do not SKIP the entire
run unless ALL criteria depend on it.

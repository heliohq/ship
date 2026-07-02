# API Testing

Verify API endpoints return correct responses and explore beyond the spec
for edge cases. You know curl; this reference fixes the process contract:
what to verify, what counts as a bug, and what evidence to save.

## Workflow

```
1. Discover     Find endpoints from spec, routes, OpenAPI, or diff
2. Authenticate Obtain tokens or session cookies
3. Verify       Test each endpoint against spec criteria
4. Explore      Beyond-spec testing on diff-affected endpoints
5. Document     Save evidence and write findings
```

## Discover

```bash
git diff main...HEAD --name-only | grep -E '(route|controller|handler|api|endpoint)'
curl -sf http://localhost:<port>/openapi.json | jq '.paths | keys[]'   # or /api-docs, /swagger.json
```

## Authenticate

Detect the auth method from the spec, code, or `.env`, then use the
matching standard pattern: Bearer token (login, capture
`.token // .access_token`), cookie session (`-c cookies.txt` / `-b
cookies.txt`), API key (`X-API-Key` header, `Authorization: ApiKey`, or
query param), Basic (`-u user:pass`), or OAuth2 refresh-token exchange.
Test every method the app supports — including sending both/mixed at once.

## Verify (per endpoint)

Always capture the status code alongside the body:

```bash
curl -s -w '\n%{http_code}' -H "Authorization: Bearer $TOKEN" http://localhost:<port>/api/resource
```

- **Body over status.** Status alone is L2 evidence; `200 OK` with a wrong
  or empty body is still a bug. Verify the body contains the expected data.
- **CRUD is the baseline** for any resource endpoint: POST → GET → PUT →
  GET (change persisted?) → DELETE → GET (expect 404, not 500).
- **Auth matrix per endpoint:** no auth → 401; wrong role → 403; expired
  token → 401 with a clear error. Don't assume auth works because one
  endpoint checks it.
- **WebSocket handshake** (server side):

  ```bash
  curl -sf -o /dev/null -w '%{http_code}' -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' -H 'Sec-WebSocket-Version: 13' \
    http://localhost:<port>/<ws-path>
  # 101 = pass; 400/426 = rejected upgrade; 404 = no route
  ```

  Client-side WebSocket behavior: see `references/browser.md`.

## Explore (beyond spec, focused on the diff)

1. **Undocumented behavior** — unexpected content types, extra fields, null values
2. **Boundary values** — empty string, max-length strings, 0, negative numbers, wrong types, empty arrays, deeply nested JSON, oversized payloads
3. **Privilege fields** — extra unexpected fields in the payload (`"admin": true`, `"role": "superuser"`) silently accepted
4. **Ordering and pagination** — page 0, negative page, huge page/limit, limit 0
5. **Rate limiting** — rapid repeated requests
6. **Cross-endpoint consistency** — write via one endpoint, verify via another
7. **Partial failures** — one field valid, another invalid
8. **Concurrency** — same resource modified simultaneously
9. **Injection** — `' OR 1=1 --` in string fields; stored `<script>` returned unescaped
10. **Streaming resilience** — early disconnect, reconnect with Last-Event-ID, slow client; bound SSE/chunked requests with `timeout`, verify captured output after
11. **Content negotiation** — wrong `Content-Type` on requests; unsupported `Accept` types
12. **CORS** (if browser-consumed) — `Access-Control-Allow-*` headers, preflight OPTIONS

## Evidence

Capture the full request/response for every test with `curl -sv`, one
file per test:

```bash
curl -sv -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" -d '{"name":"test"}' \
  http://localhost:<port>/api/resource > <qa_dir>/api-<test-name>.txt 2>&1
```

Name files by test: `api-auth-login.txt`, `api-crud-flow.txt`,
`api-pagination-negative.txt`, … A test without saved evidence cannot be L1.

## Judgment calibration

- **Test the contract, not the implementation** — what the spec/OpenAPI/types promise.
- **Idempotency:** same PUT twice → same result; DELETE of already-deleted → 404, not 500.
- **Verify side effects:** after every write, read it back; don't trust the write response.
- **Error format consistency:** all error responses share one shape; drift is a real bug.
- **Content-Type must match the body** — JSON served as `text/html` is a bug.
- **Realistic data:** plausible names/emails/values; boundaries test limits, not gibberish.
- **Document each issue immediately** — don't batch findings.

## Output

Severity definitions and report structure: `references/report.md`.
Write findings to `<qa_dir>/api-report.md` (API section).

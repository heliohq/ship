# API Testing

Verify API endpoints return correct responses.

## Basic verification

```bash
curl -sf -w '\n%{http_code}' http://localhost:<port>/<path>
```

- Verify response **body content**, not just status code
- Parse JSON and check for required fields
- Status code alone = L2. Body verification = L1.

## What to check per endpoint

1. **Happy path** — correct request → expected response
2. **Response schema** — all required fields present, correct types
3. **Error responses** — invalid input → proper error format
4. **Auth** — no token → 401, wrong role → 403
5. **Edge cases** — empty body, missing fields, extra fields

## WebSocket verification

### Server-side handshake (curl)

```bash
curl -sf -o /dev/null -w '%{http_code}' \
  -H 'Upgrade: websocket' \
  -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  http://localhost:<port>/<ws-path>
```

- 101 → PASS (Switching Protocols)
- 400/426 → FAIL (rejected upgrade)
- 404 → FAIL (route not found)
- Connection refused → service not running

### Client-side (browser)

```
mcp__chrome-devtools__list_network_requests(resourceTypes=["websocket"])
```

## Evidence levels for API testing

| What you checked | Evidence level |
|-----------------|---------------|
| Response body matches expected schema | L1 |
| HTTP status code only | L2 |
| "Server log says success" | L2 |
| "Code looks like it handles this" | L3 (FAIL) |

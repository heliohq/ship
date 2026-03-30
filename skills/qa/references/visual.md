# Visual Testing

Verify the UI looks correct through screenshots and visual inspection.

## Workflow

For each page requiring visual verification:

1. **Navigate** to the page
2. **Wait for load** (2-5 seconds for complex apps)
3. **Take screenshot** → save to `.ship/tasks/<task_id>/qa/`
4. **Check console** for errors
5. **If interactive:** perform interaction, screenshot after
6. **Compare** against expected behavior

See `strategies/web-app.md` for browser tool commands (Chrome DevTools MCP).

## Visual sanity checks

For each screenshot, verify:
- Page is NOT mostly blank/black (>80% single color = likely broken)
- Expected UI elements are visible
- No rendering artifacts or broken layout
- Text is readable (not cut off, not invisible)
- Images loaded (no broken image icons)

## Browser tool detection

Try in order, use the first that works:

1. **Chrome DevTools MCP** — `mcp__chrome-devtools__list_pages`
2. **Computer Use** — `mcp__computer-use__list_granted_applications`

## Browser unavailable

When no browser tool is available:
- MUST criteria requiring visual verification → **SKIP** (not FAIL)
- Use curl for API-level checks (L2 evidence only)
- Print setup guidance once:

```
[QA] Visual criteria need a browser. Without one, these will be SKIP.

Chrome DevTools MCP:
  claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest

Docs: https://github.com/ChromeDevTools/chrome-devtools-mcp
```

## curl is NOT a visual verification tool

- curl HTTP 200 ≠ "page renders correctly"
- curl response body ≠ "UI looks right"
- curl is L2 evidence for visual criteria — insufficient for MUST

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| Connection refused | Chrome not running | Start with `--remote-debugging-port=9222` |
| DevToolsActivePort not found | Profile locked | Close other Chrome instances |
| Empty response | MCP server crashed | Restart MCP server |
| Timeout | Chrome slow | Check system resources |

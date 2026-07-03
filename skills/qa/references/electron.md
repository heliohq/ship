# Electron App Automation

Automate any Electron desktop app using agent-browser. Electron apps are built on Chromium and expose a Chrome DevTools Protocol (CDP) port that agent-browser can connect to, enabling the same snapshot-interact workflow used for web pages.

## Core Workflow

1. **Launch** the Electron app with remote debugging enabled
2. **Connect** agent-browser to the CDP port
3. **Snapshot** to discover interactive elements
4. **Interact** using element refs
5. **Re-snapshot** after navigation or state changes

```bash
# Launch an Electron app with remote debugging
open -a "Slack" --args --remote-debugging-port=9222

# Connect agent-browser to the app
agent-browser connect 9222

# Standard workflow from here
agent-browser snapshot -i
agent-browser click @e5
agent-browser screenshot slack-desktop.png
```

## Launching Electron Apps with CDP

Every Electron app supports the `--remote-debugging-port` flag since it's built into Chromium.

Same pattern per OS, one debugging port per app:

```bash
# macOS
open -a "<App Name>" --args --remote-debugging-port=9222
# Linux
<app-binary> --remote-debugging-port=9222
# Windows
"C:\path\to\<App>.exe" --remote-debugging-port=9222
```

**Important:** If the app is already running, quit it first, then relaunch with the flag. The `--remote-debugging-port` flag must be present at launch time.

## Connecting

```bash
# Connect to a specific port
agent-browser connect 9222

# Or use --cdp on each command
agent-browser --cdp 9222 snapshot -i

# Auto-discover a running Chromium-based app
agent-browser --auto-connect snapshot -i
```

## Tab Management

Electron apps often have multiple windows or webviews. Use tab commands to list and switch between them:

```bash
# List all available targets (windows, webviews, etc.)
agent-browser tab

# Switch to a specific tab by index
agent-browser tab 2

# Switch by URL pattern
agent-browser tab --url "*settings*"
```

## Webview Support

Electron `<webview>` elements are automatically discovered and can be controlled like regular pages. Webviews appear as separate targets in the tab list with `type: "webview"`:

```bash
# Connect to running Electron app
agent-browser connect 9222

# List targets -- webviews appear alongside pages
agent-browser tab
# Example output:
#   0: [page]    Slack - Main Window     https://app.slack.com/
#   1: [webview] Embedded Content        https://example.com/widget

# Switch to a webview
agent-browser tab 1

# Interact with the webview normally
agent-browser snapshot -i
agent-browser click @e3
agent-browser screenshot webview.png
```

**Note:** Webview support works via raw CDP connection.

## Multiple Apps

Use named sessions to control multiple Electron apps at once:
`--session <name> connect <port>` per app, then address each by
`--session <name>`.

## Color Scheme

The default color scheme when connecting via CDP may be `light`. To preserve dark mode:

```bash
agent-browser connect 9222
agent-browser --color-scheme dark snapshot -i
```

## Troubleshooting

### "Connection refused" or "Cannot connect"

- See the **Important** note above on relaunching with the flag.
- Check that the port isn't in use by another process: `lsof -i :9222`

### App launches but connect fails

- Wait a few seconds after launch before connecting (`sleep 3`)
- Some apps take time to initialize their webview

### Elements not appearing in snapshot

- The app may use multiple webviews. Use `agent-browser tab` to list targets and switch to the right one

### Cannot type in input fields

- Try `agent-browser keyboard type "text"` to type at the current focus without a selector
- Some Electron apps use custom input components; use `agent-browser keyboard inserttext "text"` to bypass key events

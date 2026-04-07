# Installing Ship for Codex

Enable Ship workflow skills in Codex via native skill discovery. To install Codex hooks across repos, also install Ship's shipped hook manifest.

## Prerequisites

- Git
- OpenAI Codex CLI

## Installation

1. **Clone the Ship repository:**
   ```bash
   git clone https://github.com/heliohq/ship.git ~/.codex/ship
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/ship/skills ~/.agents/skills/ship
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\ship" "$env:USERPROFILE\.codex\ship\skills"
   ```

3. **Enable Codex features** by adding this to `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
codex_hooks = true
```

- `multi_agent` — enables subagent dispatch for skills like `implement` and `plan`
- `codex_hooks` — enables Codex's hook runtime so Codex can load hook manifests

4. **Install global Codex hooks** (macOS/Linux):

   If `~/.codex/hooks.json` does not exist yet:

   ```bash
   mkdir -p ~/.codex
   ln -s ~/.codex/ship/.codex/hooks.json ~/.codex/hooks.json
   ```

   If `~/.codex/hooks.json` already exists, do not replace it. Instead, open both files and copy the Ship hook entries from `~/.codex/ship/.codex/hooks.json` into the matching arrays in `~/.codex/hooks.json`:

   - append the entries under `hooks.SessionStart` to your existing `hooks.SessionStart`
   - append the entries under `hooks.Stop` to your existing `hooks.Stop`
   - if either array does not exist yet, create it first

   This step is what installs Codex hooks globally. Without it, Ship skills will be available, but hooks will only run in repos that already contain their own `.codex/hooks.json`.

5. **Restart Codex** (quit and relaunch the CLI) to discover the skills and hooks.

## Verify

```bash
ls -la ~/.agents/skills/ship
ls -la ~/.codex/hooks.json
jq . ~/.codex/hooks.json
```

You should see a symlink pointing to your Ship skills directory and either a symlink or a valid merged global hook manifest.

## Updating

```bash
cd ~/.codex/ship && git pull
```

Skills update instantly through the symlink.

If `~/.codex/hooks.json` is a symlink to `~/.codex/ship/.codex/hooks.json`, hook updates apply automatically after `git pull`.
If you manually merged Ship's hook entries into an existing `~/.codex/hooks.json`, re-open `~/.codex/ship/.codex/hooks.json` after updates and re-merge any changed Ship entries.

## Uninstalling

```bash
rm ~/.agents/skills/ship
```

If `~/.codex/hooks.json` is a symlink to Ship's hook manifest, remove that symlink too: `rm ~/.codex/hooks.json`

Optionally delete the clone: `rm -rf ~/.codex/ship`

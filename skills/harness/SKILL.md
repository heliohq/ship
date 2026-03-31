---
name: harness
version: 1.0.0
description: >
  Activate AI harness enforcement. Registers structural and semantic
  rule hooks in .claude/settings.json. Rules must exist in .ship/rules/.
  Use when: harness, activate rules, enable enforcement.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
---

# Ship: Harness

Activate the project's coding convention enforcement by registering
hook entries in `.claude/settings.json`.

## Principal Contradiction

**Enforcement must be opt-in yet reliable once activated.**

The harness cannot be always-on at the plugin level because different
projects have different rules. But once activated, it must reliably
intercept every Write/Edit to enforce conventions.

## Process

1. Check `.ship/rules/rules.json` exists.
   If not → tell user to run `/ship:setup` first and stop.

2. Read `.claude/settings.json` (create `{}` if missing).

3. Check if harness hooks are already registered:
   Look for a PreToolUse hook with `statusMessage` containing
   "Checking structural rules..." or command containing
   `.ship/rules/enforce-structural.sh`.
   If found → "Harness is already active." and stop.

4. Read `.ship/rules/rules.json`. Count enabled structural and semantic rules.

5. Merge two PreToolUse hook entries into `.claude/settings.json`,
   preserving all existing hooks:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [{
             "type": "command",
             "command": "bash .ship/rules/enforce-structural.sh",
             "statusMessage": "Checking structural rules..."
           }]
         },
         {
           "matcher": "Write|Edit",
           "hooks": [{
             "type": "agent",
             "prompt": "You are a code convention enforcer. Read .ship/rules/rules.json to find all enabled semantic rules. For each applicable rule (check scope against the file being written), read the rule's .md file from .ship/rules/semantic/. Then verify the code in $ARGUMENTS follows those conventions. If violations found, return JSON with hookSpecificOutput.additionalContext describing each violation and how to fix it. If no violations, return nothing.",
             "model": "claude-haiku-4-5-20251001",
             "statusMessage": "Reviewing coding conventions..."
           }]
         }
       ]
     }
   }
   ```

6. Confirm: "Harness activated. N structural + M semantic rules enabled."

## Hard Rules

1. Never create rule files. This skill only registers hooks.
2. Never modify existing hooks — only append new ones.
3. If rules.json is missing, stop immediately. Do not offer to create it.

<Bad>
- Creating .ship/rules/ directory or any rule files
- Overwriting existing hooks in settings.json
- Activating when rules.json doesn't exist
- Modifying rule files during activation
</Bad>

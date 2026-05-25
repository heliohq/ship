---
title: "Minimal Use-Ship Startup Hint"
description: "SessionStart injects only a small /ship:use-ship routing hint, not docs, memory, or artifact content."
category: "design"
number: "002"
status: current
services: [hooks, skills]
last_modified: "2026-05-25"
---

# 002 - Minimal Use-Ship Startup Hint

## Status

Current. Ship registers a minimal startup hook.

## Summary

Ship should be discoverable at the beginning of a session, but it should not
push full workflow instructions, docs indexes, design pointers, memory, or
artifact content into every conversation.

The startup hook exists only to tell the host agent that `/ship:use-ship` is
the routing entrypoint when the user's request may need Ship process.

## Decision

Register `SessionStart` / `sessionStart` hooks that emit one short routing hint.

| Concern | Behavior |
|---------|----------|
| Skill discovery | Startup hint says to consult `/ship:use-ship` when Ship may apply |
| Explicit commands | If the user names a `/ship:*` command, follow that command directly |
| Unrelated work | Do not use Ship |
| Full pipeline | Do not start `/ship:auto` unless the user asks for full end-to-end delivery |
| Docs awareness | Agents read `docs/DOCS_INDEX.md` only when needed |
| Visual design | Frontend skills read `DESIGN.md` only when needed |

This keeps Ship visible without turning every session into a Ship session.

## Boundaries

- The startup hook must stay tiny.
- Do not inject `docs/DOCS_INDEX.md`.
- Do not inject `DESIGN.md`.
- Do not inject production artifact guidance.
- Do not inject memory or retrospective notes.
- Do not force `/ship:auto` from startup context.
- Keep detailed routing in `skills/use-ship/SKILL.md`.

## References

- `scripts/session-start.sh`
- `hooks/hooks.json`
- `hooks/codex-hooks.json`
- `hooks/hooks-cursor.json`
- `skills/use-ship/SKILL.md`

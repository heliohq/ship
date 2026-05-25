# Host / Peer Runtime Resolution

Shared concepts for skills that dispatch a second independent agent (peer).
The per-skill SKILL.md decides what *role* the peer plays (investigator,
implementer, drill agent, etc.) — this file only fixes the *plumbing*:
who the host is, who the peer is, and how to dispatch each one.

## Host and peer

- **Host agent** — the provider currently running the skill (you).
- **Peer agent** — the non-host provider when available; otherwise a
  fresh same-provider session.

Resolve the peer once at the start of the skill and reuse that decision.

## Dispatch commands

| Peer | How to dispatch |
|---|---|
| Codex | `mcp__codex__codex` (first call); `mcp__codex__codex-reply` to continue the same session using the returned `session_id`. |
| Claude CLI adapter | `claude -p --permission-mode bypassPermissions`. This adapter is treated as fresh-session dispatch, so for follow-ups re-dispatch with prior context included verbatim. |
| Fallback | If neither the non-host provider nor a dispatch mechanism is available, use a fresh same-provider session and note that independence is weaker in the report. |

## Pair

- Claude host ↔ Codex peer
- Codex host ↔ Claude peer

## Session continuation (Codex only)

When a Codex peer returns, save the `session_id` from the response. For
targeted follow-ups (fix mode, debate, drill revision), reuse it:

```
mcp__codex__codex-reply({
  session_id: <saved id>,
  reply: <follow-up prompt>
})
```

If `codex-reply` fails (session expired, server error), fall back to a
fresh `mcp__codex__codex` dispatch with the prior context quoted
verbatim.

Claude CLI peer dispatch has no continuation hook in this plugin — always
re-dispatch `claude -p` with full context when you need a follow-up.

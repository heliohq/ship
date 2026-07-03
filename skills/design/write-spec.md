# Write Spec — Investigation & Spec Authoring

How to investigate a codebase and write a spec. Used by the host agent
in Phase 2-3 of `/ship:design`.

## Overview

Write the spec assuming the reader has zero context: what you found,
what you traced, and what must be true for the task to be done.

## Methodology

Your investigation method and spec structure are the **same** ones you
dispatch to the peer — the steps are role-neutral. Follow the
**Investigation** and **Write Spec** sections of the peer prompt in
`independent-investigator.md` (the same-session file you read to dispatch
the peer): trace callers backward and consumers forward, search for
existing defenses before proposing a fix, verify a file exists before
proposing to create it, grep tests that assert values you'll change,
cross-reference every consumer of a changed interface — then the "what to
include" section list and the spec self-review checklist.

Ignore the peer-framing ("you have not seen any prior spec"); apply the
steps to your own investigation and write the result to `spec.md`.

**This is the most important phase — do not rush the investigation.**
Every claim in the spec must reference a `file:line` you actually read.

## Task too vague?

After investigation, check if any of these are missing from the task
description AND could not be inferred from code:
- **Target behavior** — what should change
- **Target surface** — which files, endpoints, or components
- **Success condition** — how to know it's done

If any are missing, ask the user via AskUserQuestion before writing the
spec. (This is host-only — the peer investigator cannot ask the user.)

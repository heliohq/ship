# Ship Skills

**Start here:** use `/ship:use-ship` when the agent should decide how much Ship
process the task needs. It routes to a standalone skill, a phase bundle, or the
full `/ship:auto` workflow.

## Workflow Model

Ship should teach agents how to choose a workflow, not force every task through
predefined stage YAML.

| Need | Route |
|------|-------|
| Plan or de-risk | `/ship:design` |
| Architecture decision / ADR | `/ship:arch-design` → `/ship:write-docs`, then `/ship:design` when needed |
| Build a scoped change | `/ship:design` → `/ship:dev` |
| Implement from an existing plan | `/ship:dev` |
| Quality hardening | `/ship:e2e` → `/ship:review` → `/ship:qa` → `/ship:refactor` |
| Delivery | `/ship:handoff` |
| Full production delivery | `/ship:auto` |

| Plane | Contents | Rule |
|-------|----------|------|
| Input | Raw user/business requirements and attachments | Preserve the original ask |
| Control | Minimal runner state plus optional agent-authored notes | Do not mandate per-stage schemas |
| Output | Markdown artifacts and repository code | Human-readable deliverables and implementation |

YAML is never the deliverable. Agents may create lightweight YAML when it helps
the current task, but Ship does not prescribe stage-specific YAML files.

Atomic skills are standalone. `/ship:use-ship` coordinates them when the user
wants grouped process, but every atomic skill — `/ship:design`, `/ship:dev`,
`/ship:e2e`, `/ship:review`, `/ship:qa`, `/ship:refactor`, `/ship:handoff`,
`/ship:arch-design`, and `/ship:write-docs` — must also work directly from the
user's current request and repository state.

## Routing Skills

| Skill | Role | Delegates To |
|-------|------|--------------|
| `/ship:use-ship` | Agent-facing router for standalone skills, bundles, and full flow | focused `/ship:*` skills |
| `/ship:auto` | Full workflow runner | orchestrator script + focused skills |

## Atomic Skills

| Skill | Use |
|-------|-----|
| `/ship:design` | Adversarial spec and plan with peer challenge rounds |
| `/ship:dev` | Implement stories with tests and peer validation |
| `/ship:e2e` | Codify acceptance criteria as persistent E2E tests |
| `/ship:review` | Bug-focused diff review |
| `/ship:qa` | Exploratory verification against the running app |
| `/ship:refactor` | Behavior-preserving cleanup after quality gates |
| `/ship:handoff` | Commit, push, PR, CI, review feedback, merge readiness |
| `/ship:arch-design` | System-design thinking: nine lenses, self-interview, red-team — hands off to write-docs |
| `/ship:write-docs` | Structured documentation under `docs/`, incl. design docs and ADRs |

## `/ship:use-ship`

`/ship:use-ship` is the preferred entrypoint when the user asks Ship to help but
does not name a specific phase. It inspects the request and repo context, then
chooses the smallest useful route.

It should prefer bounded bundles over the full pipeline unless the user
explicitly wants end-to-end production delivery.

## Production Artifact Organization

When a task needs durable non-code artifacts and the repository has no existing
convention, organize only the needed files under:

```text
docs/ship/<task-id-or-req-id>/
  input/
  product/
  design/
  engineering/
  quality/
  delivery/
  archive/
```

This is a convention, not a separate command. Prefer Markdown for human-facing
artifacts. Use YAML or JSON only when structure will be consumed by a later
agent, script, or check.

## `/ship:auto`

`/ship:auto` is the end-to-end entrypoint.

The runner creates:

```text
.ship/tasks/<task_id>/
  input/
    requirement.md
```

The runner's only state surface is `.ship/ship-auto.local.md` (frontmatter:
phase, branch, session, retry counters) — used for session isolation and
resume behavior. Any additional YAML is agent-owned and task-specific.

Pipeline order today:

```text
design -> dev -> e2e -> review -> qa -> refactor -> handoff
```

Forward movement is deterministic. Review, QA, and E2E findings enter fix loops
and re-run the owning gate. QA fixes also trigger an E2E regression gate before
QA recheck.

## Quality Gates

| Gate | Required Evidence |
|------|-------------------|
| Design | `plan/spec.md`, `plan/plan.md`, peer spec, diff report |
| Dev | Branch code changes and local verification |
| E2E | `e2e/report.md` when E2E is applicable, plus test files |
| Review | `review.md` with no P1/P2 findings |
| QA | Markdown/text/log/screenshot evidence under `qa/` |
| Refactor | `refactor.md` summary and passing verification |
| Handoff | PR exists, required checks green, merge state ready |

## Discovery

Agents discover Ship through skill metadata and explicit `/ship:*` commands.
The startup hook only reminds agents to consult `/ship:use-ship` when Ship may
apply; it does not inject docs, memory, or artifact content.
Architecture thinking is handled through `/ship:arch-design`,
documentation through `/ship:write-docs`, and delivery/CI readiness
through `/ship:handoff`.

---
title: "Production Artifact Organization"
description: "Guidance for organizing requirement, design, engineering, quality, and delivery artifacts without a scaffold command."
category: "design"
number: "005"
status: current
services: ["skills", "docs"]
related: ["design/004"]
last_modified: "2026-05-25"
---

# 005 - Production Artifact Organization

## Status

Current. Ship no longer exposes a standalone artifact-scaffold skill.

## Summary

Agents sometimes need to preserve more than code: raw requirements, decisions,
design notes, architecture plans, QA evidence, release notes, and final
summaries. Ship should teach agents how to organize those artifacts, but should
not force a separate setup command or a large prebuilt tree.

## Decision

Use existing project conventions first. If the repository has no durable
artifact convention and the task needs one, create the smallest useful
task-scoped folder under `docs/ship/`.

```text
docs/ship/<task-id-or-req-id>/
  input/
    requirement.md
  product/
    requirements.md
    acceptance-criteria.md
  design/
    ui-design.md
  engineering/
    architecture.md
    implementation-plan.md
  quality/
    test-plan.md
    qa-report.md
  delivery/
    handoff.md
    release-notes.md
  archive/
    final-summary.md
```

Only create the folders that the task actually needs. A backend-only change may
need `input/`, `engineering/`, `quality/`, and `delivery/`. A UI-only task may
need `input/`, `product/`, `design/`, and `quality/`.

## Rules

- Preserve raw input before rewriting it.
- Prefer Markdown for human-facing artifacts.
- Use YAML or JSON only when structured data will be consumed by a later agent,
  script, or check.
- Keep code in the real repository tree, not in the artifact folder.
- Keep active `/ship:auto` run state in `.ship/tasks/<task_id>/`; copy or
  summarize only durable outputs into `docs/ship/<task-id-or-req-id>/` when the
  project needs versioned records.
- Do not create a full product/design/engineering tree just because Ship is
  installed.
- Do not invent a new convention if the repository already has one.

## References

- `skills/use-ship/SKILL.md`
- `docs/design/004-stage-driven-workflow.md`

---
name: arch-design
description: >
  System architecture and design thinking — requirements analysis, component design,
  data modeling, scaling strategy, and trade-off analysis. Use when: "design this system",
  "what's the architecture for", "trade-offs for X", "how should we architect",
  "system design for", "API design", "data model for", "service boundaries",
  "architecture doc", "create an ADR". When the design thinking is done, this skill
  hands off to /ship:write-docs to write the design document. Note: this is NOT for
  visual design (use /ship:visual-design) or implementation planning (use /ship:design).
---

# Architectural Design

Think through system design decisions rigorously before writing them down. This skill is about the **thinking** — requirements, components, trade-offs, boundaries. When the design is ready, hand off to `/ship:write-docs` to write the actual design document.

## Red Flag

**Never:**
- Skip requirements gathering and jump straight to a solution
- Design without understanding existing constraints (tech stack, team, timeline)
- Omit trade-off analysis — every decision has alternatives that were rejected for a reason
- Skip the Boundaries section — it's the core anti-drift mechanism
- Propose a design without verifying assumptions against the actual codebase
- Conflate "what we want" with "what exists" — be explicit about the gap

## Phase 1: Requirements Gathering

Before designing anything, understand what you're solving.

### Functional Requirements
- What must the system do? List concrete capabilities.
- What are the input/output contracts?
- What user-facing behaviors are required?

### Non-Functional Requirements
- **Latency**: What response times are acceptable? (p50, p99)
- **Throughput**: How many requests/events per second?
- **Availability**: What uptime target? (99.9%? 99.99%?)
- **Consistency**: Strong consistency required, or eventual is acceptable?
- **Data volume**: How much data now? Growth rate?

### Constraints
- Existing tech stack and infrastructure
- Team size and expertise
- Timeline and budget
- Compliance and regulatory requirements
- Backward compatibility requirements

## Phase 2: High-Level Design

Map out the major components and how they interact.

- **Component diagram**: Major services/modules and their responsibilities. Each component should have a single clear purpose.
- **Data flow**: How data moves through the system — request paths, event flows, data pipelines.
- **API contracts**: Key interfaces between components. Define input/output shapes, not implementation.
- **Storage choices**: Which database(s), why. Access patterns determine storage choice, not the other way around.

## Phase 3: Deep Dive

Go deep on the components that matter most.

- **Data model**: Entities, relationships, indexes. Think about access patterns — how will this data be queried?
- **API design**: REST vs GraphQL vs gRPC. Endpoint structure, authentication, rate limiting, versioning strategy.
- **Caching strategy**: What to cache, invalidation approach, TTL. Cache only what's read-heavy and tolerant of staleness.
- **Async and queues**: What needs to be asynchronous? Retry policies, dead-letter queues, idempotency.
- **Error handling**: Failure modes for each component. Fallback strategies, circuit breakers, graceful degradation.

## Phase 4: Scale and Reliability

Design for the load you'll actually face, not hypothetical scale.

- **Load estimation**: Back-of-envelope calculations for storage, bandwidth, compute. Ground these in real numbers.
- **Scaling strategy**: Horizontal vs vertical. Sharding strategy if needed. Read replicas.
- **Failover**: What happens when each component fails? Single points of failure?
- **Monitoring**: Key metrics to track, alerting thresholds, dashboards. What does "healthy" look like?

## Phase 5: Trade-off Analysis

Every design decision has trade-offs. Make them explicit.

For each major decision:
- **What alternatives were considered** (at least 2)
- **Pros and cons of each** (concrete, not vague)
- **Why this choice won** (the deciding factor)
- **What we're giving up** (be honest about costs)

Common trade-off dimensions:
- Consistency vs availability
- Simplicity vs flexibility
- Build vs buy
- Latency vs throughput
- Cost vs performance
- Team familiarity vs best tool for the job

## Design Document Output

When the design thinking is complete, the result should be written as a design document. Every design doc needs:

- **Boundaries section** (required) — what this design does NOT cover, what must not change without updating this doc. This is the core anti-drift mechanism.
- **Trade-offs section** (recommended) — the alternatives considered and why this choice won.
- **Assumptions section** (recommended) — what must be true for this design to hold (e.g., "assumes < 10k concurrent users", "assumes single-region deployment"). When assumptions change, the design is stale.

To write the design document, use `/ship:write-docs` with category `design`.

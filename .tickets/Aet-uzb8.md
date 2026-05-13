---
id: Aet-uzb8
status: closed
deps: [Aet-q4wg]
links: []
created: 2026-05-13T12:15:23Z
type: task
priority: 2
assignee: lispmeister
parent: Aet-1347
---
# Implement deterministic simulation harness

Create the library-side simulation harness for isolated replay of trace-derived inputs and patch deltas, without adding demo or deployment logic.

## Acceptance Criteria

Simulations run in isolation; trace replay is deterministic for supported cases; outputs include diffs, invariant deltas, and failure classification.


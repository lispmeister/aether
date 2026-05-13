---
id: Aet-dse5
status: closed
deps: [Aet-vt6m]
links: []
created: 2026-05-13T12:15:23Z
type: task
priority: 2
assignee: lispmeister
parent: Aet-1347
---
# Implement provenance storage and review records

Add append-only provenance records for proposals, reviews, and simulation runs, with durable storage and a cache layer if needed.

## Acceptance Criteria

Proposal and review events can be recorded durably; provenance records include the required fields; ETS is used only as cache if present.


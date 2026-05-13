---
id: Aet-q4wg
status: closed
deps: [Aet-mmxa]
links: []
created: 2026-05-13T12:15:23Z
type: task
priority: 1
assignee: lispmeister
parent: Aet-1347
---
# Implement Aether.Reflect mirror API

Build the runtime mirror API for modules and registered processes, including snapshot shape, redaction rules, and safe read-only access.

## Acceptance Criteria

Aether.Reflect.mirror/1 returns a structured snapshot; the schema is versioned; secret redaction and privilege boundaries are defined.


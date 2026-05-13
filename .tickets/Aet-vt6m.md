---
id: Aet-vt6m
status: closed
deps: [Aet-gxil]
links: []
created: 2026-05-13T12:15:23Z
type: task
priority: 1
assignee: lispmeister
parent: Aet-1347
---
# Implement metadata extraction and validation

Collect module metadata, validate annotation structure, and persist canonical structured metadata outside __info__/1 using a durable or build-time artifact.

## Acceptance Criteria

Metadata can be extracted from annotated modules; invalid forms produce diagnostics; records are versioned and keyed by module and digest.


# Aether

Aether makes long-running Elixir/OTP systems legible to AI maintainers without handing them authority.

It is a thin governance layer over Elixir that adds explicit intent, structured invariants, runtime mirrors, traceable simulation, provenance, and human review for risky changes. The goal is not autonomous rewriting. The goal is a safer maintenance loop for live systems that need to evolve over time.

## What It Is

- `@intent` for module purpose
- `@invariant` for structured safety rules
- runtime mirrors for machine-readable snapshots of live state
- simulation for rehearsing candidate changes in isolation
- provenance for durable change history
- review packets for human approval when needed

## What It Is Not

- a new language
- a BEAM fork
- a hot-patching framework with unconditional authority
- an autonomous production editor

## Core Loop

```text
observe -> mirror -> simulate -> review -> apply through OTP -> verify
```

## Why Elixir + OTP

Elixir already gives Aether the right foundation:

- explicit processes and supervision
- mature live-system primitives
- hot-code upgrade paths
- compile-time macros and metadata
- a runtime that is already built for long-lived services

## MVP

The first runnable version is intentionally narrow:

- one GenServer
- `@intent` and `@invariant` capture
- a mirror API
- deterministic trace replay
- a minimal simulation harness
- provenance recording
- a CLI review stub

## Getting Started

Read [AETHER-HOWTO-GET-STARTED.md](./AETHER-HOWTO-GET-STARTED.md) for the recommended prototype shape and demo project.

## Status

This repository is currently a spec and implementation guide for the Aether concept. The immediate focus is proving the core loop on a small Payments or Ledger demo before expanding into rollout and control-plane features.

# Aetherlang + Eigenforge

## Core Thesis

Apply Aetherlang to Eigenforge as an **agent-operability layer over a safety-critical Elixir/OTP control OS**, not as a replacement for Eigenforge's authority model.

```text
Eigenforge OS = runtime authority plane
Aetherlang     = AI comprehension, diagnosis, simulation, and evolution plane
```

Eigenforge defines the trusted operational path:

```text
snapshot
  -> reasoner
  -> capability
  -> policy
  -> finalized ledger
  -> signed command
  -> IO
  -> after-action
```

Aetherlang defines the AI maintenance path:

```text
intent
  -> invariants
  -> reflection
  -> simulation
  -> provenance
  -> human verification
  -> controlled rollout
```

The combined system should let an AI agent understand, verify, and safely evolve Eigenforge over time while preserving Eigenforge as the only authority-bearing control plane.

## How The Ideas Fit

### Eigenforge Contributes

- A crisp control-loop architecture.
- Strict responsibility boundaries between contracts, IO, core, mailbox, and dashboard.
- Signed contracts and signed command envelopes.
- Append-only durable decision/action ledgers.
- A single-core V1 finalization boundary that extends cleanly to V2 quorum.
- Deterministic simulator and golden trace infrastructure.
- A clear distinction between ephemeral live state and durable control facts.

### Aetherlang Contributes

- Machine-readable module intent and invariants.
- A compiler/metadata layer optimized for AI authorship and maintenance.
- Runtime mirrors that present live system state in agent-friendly form.
- A simulation universe for counterfactual execution and patch validation.
- A human verification loop for non-trivial system changes.
- Provenance over the lifecycle of proposed changes and accepted repairs.

## Recommended Integration Model

### 1. Add Aether Metadata To Eigenforge's Critical Modules

The first integration step is to annotate the modules that encode OS-level safety and authority.

Recommended targets:

- `Core.Reasoner`
- `Core.CapabilityChecker`
- `Core.PolicyEngine`
- `Core.CommandIssuer`
- `Core.AfterActionObserver`
- `Ledger.Writer`
- `IO.CommandExecutor`

Example:

```elixir
defmodule Eigenforge.Core.CommandIssuer do
  @intent "Issue physical commands only after finalized durable authorization"
  @invariant "no command envelope exists without prior committed finalized ledger event"
  @invariant "every command references a consensus_decision_id and idempotency key"
  @behaviour Aether.AgentBehaviour
end
```

These annotations should capture Eigenforge's core safety laws, not generic prose. They are meant to become:

- compiler-checkable metadata where possible;
- runtime mirror fields;
- review prompts for human approval;
- simulation assertions;
- documentation for agent reasoning.

### 2. Build Runtime Mirrors Over Eigenforge Control State

Aetherlang's runtime reflection should become the primary AI-facing introspection layer for Eigenforge.

It should aggregate:

- current normalized IO state;
- latest durable control projection;
- pending command lifecycle state;
- recent decision chain;
- latest after-action status;
- IO degradation or fault context;
- ledger tail integrity summary;
- invariant status.

Illustrative shape:

```elixir
%{
  room_id: "lab",
  live_state: %{
    co2_ppm: 1200,
    fan_state: "off",
    freshness: "fresh"
  },
  control_chain: %{
    latest_reasoner: "propose_action:fan_on",
    latest_policy: "allow",
    pending_command_id: nil,
    latest_after_action: "confirmed_changed"
  },
  ledger: %{
    latest_sequence: 184,
    hash_chain_status: :ok,
    last_event_type: "after_action_recorded"
  },
  invariants: [
    %{name: "ledger_before_command", status: :ok},
    %{name: "no_unsigned_command", status: :ok},
    %{name: "stale_co2_never_commands", status: :ok}
  ],
  faults: []
}
```

This mirror should intentionally sit above several Eigenforge internals:

- live IO streams;
- durable ledger records;
- read-model projections;
- process health and OTP supervision state.

The AI agent should not need to reconstruct the system by manually querying five subsystems independently.

### 3. Treat Eigenforge Golden Traces As Aether's First Simulation Backend

Eigenforge already specifies the right simulation foundation:

- normalized snapshot fixtures;
- deterministic IDs and timestamps;
- a trace runner;
- ledger verification;
- acceptance traces for fan-on, no-action, and stale-deny paths.

That should become the first practical implementation of `Aether.Simulator`.

The simulator layer should add:

- trace clustering;
- fault classification;
- counterfactual scenario generation;
- replay against a proposed patch;
- invariant delta reporting;
- regression summaries for human review.

Do not build a second, disconnected simulation framework. The Eigenforge golden trace runner is already the right executable contract for the control loop.

### 4. Use Separate Ledgers For Runtime Authority And Engineering Provenance

Eigenforge's local SQLite ledger should remain narrowly authoritative over control facts:

- reasoner outcomes;
- capability checks;
- policy decisions;
- issued command envelopes;
- relevant IO faults;
- after-action events.

Aetherlang should introduce a **separate engineering provenance ledger** for:

- patch proposals;
- rationale;
- simulation results;
- changed invariants;
- human approvals or rejections;
- rollout decisions;
- production validation results.

These ledgers should cross-reference one another when useful through fields such as:

- `patch_id`;
- `trace_id`;
- `correlation_id`;
- `ledger_event_hash`;
- `consensus_decision_id`.

This separation matters. Runtime control history and engineering-change history are related, but they are not the same class of truth.

### 5. Preserve Eigenforge As The Only Control Authority

This is the most important design rule.

Aether may:

- inspect mirrors;
- diagnose failures;
- run simulations;
- propose code changes;
- propose config changes;
- prepare migrations;
- generate verification packets;
- recommend operational responses.

Aether must not:

- issue actuator commands outside Eigenforge's signed command path;
- mutate or rewrite ledger rows;
- bypass mailbox delivery rules;
- bypass capability or policy checks;
- act as an alternate runtime authority.

In compact form:

```text
Aether may evolve Eigenforge.
Aether must not become an alternate control authority.
```

## Combined Architecture

```text
Aether Compiler Layer
- @intent / @invariant / structured AST metadata
- contract linting
- invariant extraction

Eigenforge Runtime OS
- contracts
- IO streams
- OODA core
- capability + policy
- ledger
- mailbox
- after-action

Aether Reflection Layer
- mirrors over OTP processes
- mirrors over ledger and projections
- invariant status APIs
- agent-oriented diagnostics

Aether Simulation Layer
- wraps Eigenforge golden trace runner
- fault injection
- counterfactual replay
- patch validation

Aether Human Verification Layer
- review proposed code/config/spec changes
- show diff + traces + invariant delta
- approve / reject / modify with rationale
```

## Where The Combination Is Strongest

### Incident Diagnosis

Example question:

```text
Why did no fan command issue?
```

The mirror should answer directly:

- CO2 observation was stale;
- reasoner returned `insufficient_fresh_data`;
- policy denied action;
- no command envelope was created;
- ledger chain is intact;
- latest relevant fault event explains the degraded context.

### Control Decision Explanation

Humans and agents should be able to inspect one full causal path:

```text
snapshot
  -> reasoner
  -> capability
  -> policy
  -> durable event chain
  -> command delivery
  -> after-action interpretation
```

This turns Eigenforge from a black box into a explainable control OS.

### Safe Policy Evolution

When Eigenforge later adds:

- hysteresis;
- dwell-time control;
- multi-room behavior;
- quorum-based finalization;

Aether can:

- extract affected invariants;
- propose changes;
- run golden trace comparisons;
- generate patch verification bundles;
- present a human approval surface with concrete before/after behavior.

### Multi-Core Quorum Migration

The V2 Eigenforge shift to three-core voting introduces new invariants:

- no non-quorum command finalization;
- no stale-node authority;
- append-only catch-up behavior;
- no duplicate finalized decisions;
- no foreign hash reuse in local ledgers.

Aether's intent/invariant model is well suited to expressing, validating, and regression-testing those transition rules over time.

## Suggested Implementation Sequence

1. Add Aether metadata and invariants to Eigenforge's core decision and actuation modules.
2. Implement `Aether.Reflect` views for:
   - OODA core state;
   - ledger writer state;
   - IO command execution state;
   - room control projection state.
3. Treat the existing golden trace runner as the initial `Aether.Simulator` backend.
4. Build a review artifact that shows:
   - proposed patch diff;
   - impacted invariants;
   - golden trace changes;
   - ledger verification outcome.
5. Keep all physical actuation authority entirely inside Eigenforge's existing signed and ledger-backed flow.

## Final Position

Eigenforge should be the **constitution and machinery of the autonomous control OS**.

Aetherlang should be the **language and tooling that let an AI agent understand, verify, and safely evolve that OS over time**.

The combined architecture is stronger than either idea alone:

- Eigenforge gives Aether a real authority model and a rigorous operational substrate.
- Aether gives Eigenforge an AI-native maintenance, diagnosis, and evolution layer.


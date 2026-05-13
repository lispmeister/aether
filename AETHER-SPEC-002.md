# Aether Specification

**AI Agent-First Programming Model as Thin Extensions to Elixir + OTP**  
**Version: 2.0**  
**Target:** Elixir `~> 1.20` / OTP `>= 27`  
**Scope:** long-running production systems that need AI-assisted maintenance, diagnosis, simulation, and controlled evolution  
**Principle:** Aether increases legibility and governance. It does not become an alternate authority plane.

## 1. Purpose

Aether makes an Elixir/OTP system easier for an AI maintainer to understand and safely evolve by adding:
- explicit intent;
- explicit invariants;
- runtime mirrors;
- traceable simulation;
- provenance over proposed changes;
- human review for high-risk actions.

The intended output is not autonomous rewriting of production systems. The intended output is a governed maintenance loop where an AI can inspect, propose, rehearse, and prepare changes while the existing application authority model remains intact.

## 2. Core Model

Aether has three layers:

1. Metadata layer
   - `@intent`
   - `@invariant`
   - `@recovery`
   - `@on_failure`
   - module and change provenance

2. Observation layer
   - runtime mirrors
   - telemetry
   - trace capture
   - redaction
   - schema versioning

3. Change-governance layer
   - simulation
   - patch proposal packets
   - human review
   - staged rollout
   - rollback

The layers are intentionally separate. Observation does not imply authority. Simulation does not imply deployment. Human review does not disappear for high-risk changes.

## 3. Non-Goals

Aether does not:
- replace Elixir or OTP;
- change the BEAM VM;
- add new syntax;
- issue authority-bearing runtime commands outside the application’s existing control plane;
- treat hot patching as unconditional;
- assume all code can be proven safe automatically;
- provide blanket guarantees that a patch cannot crash a node.

## 4. Compiler and Metadata Capture

### 4.1 Source-Level Annotations

Modules opt in by using `Aether`:

```elixir
defmodule Payments do
  use Aether

  @intent "Process payment with exactly-once semantics and ledger audit"
  @invariant "balance >= 0"
  @invariant "idempotent under req.id"
  @recovery {:on_invariant_violation, :replay_from_ledger_snapshot}
  @on_failure guardian: :escalate_to_human

  def process_payment(req) do
    :ok
  end
end
```

`use Aether` must register attributes in a way that supports accumulation and later extraction:
- `@intent` is a single string or structured intent term;
- `@invariant` is accumulate-on-write;
- `@recovery` is a constrained action descriptor;
- `@on_failure` is policy metadata.

### 4.2 Compiler Integration

Aether should not assume a custom `Mix.Task.Compiler` can intercept Elixir’s internal phases directly. The implementation should use one or more of:
- compiler tracers;
- macro hooks such as `@before_compile`;
- persisted module attributes;
- post-compilation BEAM metadata extraction;
- a Mix compiler task that validates collected metadata and writes artifacts.

The compiler layer is responsible for:
- validating annotation structure;
- collecting module metadata;
- extracting a canonical representation of intent and invariants;
- emitting structured diagnostics;
- persisting provenance records.

### 4.3 Persisted Artifacts

Aether persists metadata outside `__info__/1`. Approved storage targets are:
- BEAM chunks or compiled metadata artifacts;
- ETS for ephemeral runtime lookup;
- a durable provenance store for change history;
- optional sidecar files under `_build`.

Each stored record should be versioned and keyed by at least:
- module name;
- source digest;
- schema version;
- build or trace ID.

## 5. Invariants

`@invariant` values must become structured data, not just prose strings.

An invariant record should contain:
- `id`
- `expression`
- `scope`
- `severity`
- `source_location`
- `status`
- `last_checked_at`

Supported invariant forms are intentionally constrained. The first version may accept:
- a string expression;
- a quoted DSL term;
- or a small typed predicate structure.

The spec should not claim theorem proving. Aether is allowed to:
- parse invariants;
- statically validate invariant shape;
- evaluate invariants at runtime when safe;
- replay them in simulation;
- report violations with context.

The spec should not claim that all invariants are fully decidable or always compile-time checkable.

## 6. Runtime Mirrors

### 6.1 Purpose

A runtime mirror is a machine-consumable snapshot of a shepherded system segment. It helps an AI answer questions like:
- what is running;
- which invariants are currently healthy;
- what changed recently;
- what causal path led here;
- what the current risk is.

### 6.2 Mirror API

`Aether.Reflect.mirror/1` should return a structured snapshot for a module, PID, or explicitly registered process group.

Example shape:

```elixir
%{
  subject: Payments,
  version: 1,
  state: %{},
  invariants: [
    %{id: "balance_non_negative", status: :ok, last_checked_at: ~U[2026-05-13 00:00:00Z]}
  ],
  telemetry: %{},
  history: %{},
  actors: %{},
  redactions: [%{field: "token", reason: "secret"}]
}
```

### 6.3 Mirror Rules

Mirrors must define:
- redaction behavior;
- timeouts;
- snapshot freshness;
- privileged versus non-privileged fields;
- handling for non-GenServer processes;
- schema versioning.

Mirror access is opt-in. A module only participates if it uses `Aether` or an equivalent explicit registration mechanism.

Mirror inspection does not imply that the caller can mutate the process.

### 6.4 Control Plane

The AI-facing interface should be a single typed control surface, such as `Aether.Control`.

The control plane may expose JSON over:
- HTTP;
- WebSocket;
- TCP;
- or distributed Erlang.

The transport is separate from the internal API and must enforce authentication and authorization.

## 7. Simulation

### 7.1 Purpose

`Aether.Simulator` replays production traces and rehearses candidate patches in an isolated environment.

### 7.2 Fidelity

The simulation target is high-fidelity OTP replay, not perfect magical equivalence.

It should preserve:
- message ordering where possible;
- process topology;
- state transitions;
- trace-derived inputs;
- invariant checks;
- patch deltas.

It should explicitly model or stub:
- external IO;
- timers;
- randomness;
- distributed nodes;
- databases;
- ports and NIFs;
- wall-clock dependencies.

### 7.3 Isolation

Simulation must run in an isolated child supervision tree or separate node namespace.

If a candidate patch needs side-by-side comparison with live code, use one of:
- a separate node;
- a separate release artifact;
- a temporary renamed module namespace;
- or container/process isolation.

The spec must not assume two versions of the same module can be safely hot-loaded into a single runtime for arbitrary shadow execution.

### 7.4 Outputs

Each simulation run should produce:
- trace ID;
- patch ID;
- state diffs;
- invariant deltas;
- replay logs;
- failure classification;
- rollout recommendation.

## 8. Provenance

Every change proposal should produce a provenance record.

Minimum provenance fields:
- `proposal_id`
- `module`
- `source_digest`
- `trace_id`
- `simulation_id`
- `generated_by`
- `reviewer`
- `decision`
- `timestamp`
- `rationale`
- `artifact_hash`

Provenance should be append-only and durable. ETS is acceptable only as a cache, not as the canonical record.

## 9. Human Review

High-risk changes require human review.

The review artifact should show:
- patch diff;
- intent context;
- affected invariants;
- simulation results;
- before/after behavior;
- rollout recommendation;
- provenance chain.

Review actions are:
- accept;
- reject;
- modify with rationale.

The review step may be CLI-first for the MVP and later replaced by richer surfaces.

## 10. Live Change Flow

The live maintenance loop is:

1. Observe current runtime state.
2. Capture trace, telemetry, and provenance context.
3. Propose a patch.
4. Validate metadata and invariant shape.
5. Simulate the patch in isolation.
6. Generate a review packet.
7. Obtain approval when required.
8. Apply the change through standard OTP mechanisms.
9. Monitor rollout.
10. Record post-deploy outcomes.

### 10.1 Rollout Constraints

Live rollout must specify:
- application upgrade path;
- state migration path;
- rollback path;
- canary or staged deployment strategy;
- forbidden change classes.

`zero-downtime` is a target, not a promise.

### 10.2 Rollback

Auto-rollback may be triggered by:
- invariant violations;
- health regressions;
- rollout failures;
- control-plane errors;
- simulation-to-production divergence beyond tolerance.

Rollback behavior must be defined per application.

## 11. Safety and Security

Aether must be designed as a constrained observer and proposer.

Required safety properties:
- authentication on control endpoints;
- authorization for mirror depth and patch actions;
- secret redaction by default;
- least-privilege access;
- audit logging;
- capability checks for privileged operations;
- an emergency disable switch;
- signed or otherwise attributable patch proposals where appropriate.

The spec does not claim a patch cannot harm the system. It claims the system will make harm more detectable, more reviewable, and more reversible.

## 12. Diagnostic Output

Aether should emit structured diagnostics with:
- severity;
- message;
- file;
- position;
- module;
- confidence;
- suggested fix or patch hint;
- schema version.

Structured diagnostics are for both tooling and AI consumption. Human-readable summaries are still required.

## 13. MVP

The first runnable version should be intentionally narrow:
- one GenServer or equivalent OTP worker;
- metadata capture for `@intent` and `@invariant`;
- a mirror API for that worker;
- deterministic trace replay;
- a minimal simulation harness;
- provenance recording;
- a CLI review stub;
- no autonomous production mutation.

The MVP is complete when the full loop works on a single example service:
observe -> mirror -> simulate -> review -> apply through normal OTP upgrade path -> verify.

## 14. Example Module

```elixir
defmodule Payments do
  use Aether

  @intent "Process payment with exactly-once semantics and ledger audit"
  @invariant "balance >= 0"
  @invariant "idempotent under req.id"
  @recovery {:on_invariant_violation, :replay_from_ledger_snapshot}

  def process_payment(req) do
    :ok
  end
end
```

This example is intentionally plain. The point of Aether is not exotic syntax. The point is explicit metadata, safer observability, and governed evolution.

## 15. Implementation Order

1. Implement `Aether` macros and attribute registration.
2. Implement metadata extraction and validation.
3. Implement `Aether.Reflect` with a safe snapshot API.
4. Implement `Aether.Simulator` for isolated replay.
5. Implement provenance storage.
6. Implement a CLI review stub.
7. Implement rollout integration using standard OTP upgrade mechanics.
8. Add a single end-to-end example and tests.

## 16. Success Criteria

Aether is working when:
- a module can opt in without syntax changes;
- the system can explain its live state through a mirror;
- invariants are structured and checkable;
- a candidate patch can be simulated before rollout;
- review records are durable and auditable;
- rollout uses standard OTP mechanisms;
- authority remains with the host application, not with Aether.


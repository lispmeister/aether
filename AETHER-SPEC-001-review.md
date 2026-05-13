# AETHER-SPEC-001 Review

This is a critique of the initial sketch in `AETHER-SPEC-001.md`, with context from `AETHERLANG-004.md` and `AETHERLANG-EIGENFORGE.md`.

## Summary

The core idea is strong: Aether should make Elixir/OTP systems more legible to an AI maintainer through intent, invariants, runtime mirrors, simulation, provenance, and human review. The main problem is that the spec currently treats several hard engineering problems as already-solved implementation details. It reads more like a vision document than a spec ready for direct implementation.

The best framing is:
- Aether is a comprehension and governance layer over Elixir/OTP.
- It should not become an alternate authority plane.
- It should start with safe, narrow MVP semantics rather than full live patching, full-fidelity replay, and autonomous repair.

## Major Issues

### 1. The compiler pipeline claim is likely inaccurate

The spec says the custom compiler pass runs after macro expansion and before Erlang Abstract Format. A `Mix.Task.Compiler` does not naturally slot into Elixir’s internal compilation pipeline at that phase. If this is meant to work in practice, the spec needs to name a real mechanism:
- compiler tracers;
- macro hooks;
- `@before_compile`;
- post-compilation BEAM inspection;
- or a custom source preprocessing step.

Right now the placement is too confident for the mechanism described.

### 2. Metadata storage is underspecified

The spec says to store canonical AST and provenance metadata in module `__info__` or a companion ETS table. `__info__/1` is not a general-purpose extension point for arbitrary metadata, so that part is misleading.

A realistic design needs to say where metadata actually lives:
- module attributes persisted into BEAM chunks;
- ETS keyed by module and digest;
- `:persistent_term`;
- or an external durable store.

### 3. Invariants are not formal enough yet

The current invariant example is just a list of strings. That is fine for prose, but not enough for validation, simulation, or runtime checking.

Missing pieces include:
- invariant syntax or DSL;
- invariant names and stable IDs;
- severity and scope;
- what variables an invariant may reference;
- how invariant evaluation works;
- how failures are classified;
- whether invariants are compile-time, runtime, or simulation-only.

### 4. Runtime mirrors are too broad and too dangerous

The mirror API is plausible in spirit, but the surface is underdefined. The spec needs explicit rules for:
- redaction of secrets;
- per-module mirror schemas;
- timeout and backpressure behavior;
- how non-GenServer processes are represented;
- snapshot versus streaming semantics;
- versioning of mirror output;
- privilege boundaries for pause/resume or deep inspection.

The current text makes mirror access sound simpler and safer than it is.

### 5. Simulation fidelity is overstated

The spec claims full BEAM fidelity and the exact same bytecode as production. In practice, simulation fidelity depends on how external boundaries are handled:
- IO;
- timers;
- randomness;
- databases;
- distributed Erlang;
- NIFs and ports;
- wall-clock time;
- message ordering;
- module versioning.

The spec should say “high-fidelity OTP replay with declared adapters and fixtures,” not imply everything is automatically exact.

### 6. Hot patching is underdescribed

Hot swap via `:code.load_file` or application upgrade is not enough detail for a real live system. The spec needs to define:
- `.appup` / `relup`;
- `code_change/3`;
- state migration;
- rollback behavior;
- restart policy;
- dependency upgrade rules;
- what kinds of changes are disallowed in live rollout.

“Zero downtime” should be treated as a goal, not a guarantee.

### 7. The safety guarantee is too strong

The claim that BEAM isolation plus invariant proofs means no single patch can take down the node is too broad. A bad patch can still:
- consume memory;
- flood mailboxes;
- block schedulers through NIFs or ports;
- destabilize shared dependencies;
- break the control plane;
- cause restart loops.

The spec should convert that into a risk-reduction statement, not a proof-like guarantee.

### 8. The security model is too thin

The spec mentions a simple capability system, but an AI-facing live maintenance plane needs much more:
- authentication;
- authorization;
- transport security;
- audit logging;
- secret handling;
- least-privilege mirror access;
- emergency disablement;
- signed patch proposals;
- autonomous-action policy.

The Eigenforge context is especially important here: Aether must not become an alternate runtime authority.

## Missing Sections

The spec would be materially stronger with explicit sections for:
- terminology definitions for intent, invariant, mirror, patch, provenance event, and recovery;
- threat model;
- failure model;
- JSON schemas for mirrors, diagnostics, traces, and provenance records;
- versioning rules for metadata and replay artifacts;
- persistence choice for provenance;
- operational modes such as dev, staging, prod, proposal-only, and supervised-apply;
- evaluation metrics for the MVP;
- recovery semantics for `@recovery`;
- human approval policy;
- integration with existing ExUnit and property tests.

## Recommended Reframe

The cleanest architecture is to split Aether into three layers:

1. Metadata layer
   - `@intent`
   - named invariants
   - module metadata
   - provenance IDs

2. Observation layer
   - runtime mirrors
   - telemetry
   - trace capture
   - redaction
   - schemas

3. Change-governance layer
   - simulation
   - proposal packets
   - human review
   - staged rollout
   - rollback
   - provenance

For the Eigenforge integration, the key rule should be generalized into the main spec:

- Eigenforge is the authority plane.
- Aether is the comprehension, diagnosis, simulation, and evolution plane.
- Aether may inspect, simulate, propose, and prepare changes.
- Aether must not directly bypass authority paths or mutate control-plane state outside the authority model.

## Practical MVP Scope

The spec is strongest if the first implementation is narrow:
- one `GenServer`;
- `@intent` and `@invariant` metadata capture;
- a safe mirror API;
- deterministic replay for one workflow;
- a structured review packet;
- no autonomous production mutation.

That gives a credible first loop without pretending the hardest parts are already solved.

## Bottom Line

The concept is solid, and the motivation is coherent with the project docs. The main weakness is overclaiming implementation completeness. The next draft should replace broad promises with precise boundaries, real storage and compilation mechanisms, explicit safety constraints, and a smaller MVP that can actually be shipped and tested.


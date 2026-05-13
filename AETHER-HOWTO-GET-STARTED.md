# Aether How to Get Started

The best way to start is with a narrow, local prototype that proves the core loop before you touch anything ambitious.

## Recommended Starting Point

Build two apps in a small umbrella project:

1. `aether`
   - Core library
   - `Aether` macro for `@intent`, `@invariant`, `@recovery`, and `@on_failure`
   - Metadata extraction and validation
   - `Aether.Reflect.mirror/1`
   - `Aether.Simulator.replay/2`
   - Provenance recording
   - CLI review stub

2. `aether_demo`
   - One supervised OTP service that uses Aether
   - One realistic example domain
   - One end-to-end maintenance loop

## Best Demo Project

Use a small Payments or Ledger GenServer rather than a Todo app.

A payments-style demo gives you useful invariants immediately:

- balance must not go negative
- request IDs must be idempotent
- every action should be traceable

Example:

```elixir
defmodule Payments do
  use Aether

  @intent "Process payments exactly once and maintain an auditable ledger"
  @invariant %{id: :balance_non_negative, expression: "balance >= 0", severity: :critical}
  @invariant %{id: :idempotent_request, expression: "request_id processed at most once", severity: :critical}

  def process_payment(req) do
    :ok
  end
end
```

This is a better demo than a Todo app because it exercises the parts of Aether that matter:

- explicit intent
- structured invariants
- runtime mirrors
- deterministic replay
- provenance
- review before change

## First Prototype Milestone

Start with this loop only:

1. annotate a GenServer with `use Aether`
2. compile and persist metadata
3. mirror live state from the process
4. capture a deterministic trace
5. replay the trace in isolation
6. generate a review packet
7. append a provenance record
8. verify the result in tests

That is enough to validate the project without taking on hot patching, distributed control planes, or autonomous code mutation too early.

## What To Defer

Do not start with these:

- hot code upgrades
- distributed Erlang
- WebSocket or HTTP control planes
- AI-generated patches
- BEAM chunk manipulation
- theorem proving

Those are later milestones, not first-pass requirements.

## Suggested Project Shape

```text
mix new aether_proto --umbrella
apps/aether
apps/aether_demo
```

The success condition for the first version should be simple:

```text
annotated GenServer -> mirror -> replay -> review packet -> provenance
```

If that loop feels useful on the Payments demo, then add rollout mechanics and a richer control plane afterward.

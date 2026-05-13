# Aether Specification  

**AI Agent-First Programming Model as Thin Extensions to Elixir + OTP**  
**Version: 1.0 (Condensed for LLM Review & Implementation)**  
**Target:** Elixir v1.19+ / v1.20 (gradual set-theoretic typing available) + OTP 27+  
**Goal:** Turn any Elixir/OTP codebase into a live, self-shepherding system where an LLM-based AI agent is the primary maintainer. Focus exclusively on **long-running live production environments** (maintenance, evolution, resilience). Zero runtime overhead for non-Aether code.

### 1. High-Level Architecture (Three Interlocking Components)

**Component 1 – AI-First Programming Model**  
- Extend Elixir with macros + behaviours + custom compiler pass.  
- Human-readable idiomatic Elixir source.  
- LLM-primary: structured canonical AST + metadata stored in module.

**Component 2 – Simulation Universe (`Aether.Simulator` OTP app)**  
- Isolated supervision trees that replay production traces at full BEAM fidelity.  
- Generates structured training data for the AI agent.

**Component 3 – Human Interaction Layer**  
- `@intent` + provenance graph + interactive “accept/reject with rationale” workflow.  
- Keeps humans in the loop for high-level specification and final verification.

The three components form a closed loop: **observe (mirrors) → simulate → propose patch → human verify → hot-apply → learn**.

### 2. Required Elixir/OTP Extensions (Implementation Order)

#### 2.1 Custom Mix Compiler (`Mix.Tasks.Compile.Aether`)
- Implement `Mix.Task.Compiler` behaviour.
- Add to `mix.exs`: `compilers: Mix.compilers() ++ [:aether]`.
- Runs **after** macro expansion, **before** Erlang Abstract Format.
- Responsibilities in `run/1`:
  - Traverse expanded AST.
  - Validate `@intent`, `@invariant`, `@recovery`, `@behaviour Aether.AgentBehaviour`.
  - Convert invariants to structured metadata (leverage v1.20 gradual types where possible).
  - Store canonical structured AST + provenance metadata in module’s `__info__` or companion ETS table.
  - Emit **structured diagnostics** (JSON + NL summary, confidence, suggested patch).

#### 2.2 Behaviours & Module Attributes (in `lib/aether.ex`)
```elixir
defmodule Aether.AgentBehaviour do
  @callback mirror() :: map()               # runtime mirror (see 3.1)
  @callback invariants() :: [map()]
end

defmodule Aether do
  defmacro __using__(_) do
    quote do
      @behaviour Aether.AgentBehaviour
      @intent nil
      @invariant []
      @recovery nil
      @on_failure nil
    end
  end
end
```

Usage example (user code):
```elixir
defmodule Payments do
  use Aether
  @intent "Process payment with exactly-once semantics and ledger audit"
  @invariant ["balance >= 0", "idempotent under req.id"]
  @recovery "on invariant_violation: replay_from_ledger_snapshot"
  @on_failure guardian: :escalate_to_human

  def process_payment(req) do
    # normal Elixir code
  end
end
```

#### 2.3 Runtime Mirrors (`Aether.Reflect` OTP application)
- GenServer that registers every Aether-aware process.
- API:
  ```elixir
  {:ok, mirror} = Aether.Reflect.mirror(Payments)   # or by PID / module
  # mirror = %{
  #   state: %{...},
  #   invariants: [%{predicate: "...", status: :ok, last_checked: ~U[...] }],
  #   telemetry: %{qps: 120, error_rate: 0.0, ...},
  #   history: provenance_graph_slice(...),
  #   actors: %{...}
  # }
  ```
- Built on `:sys.get_state`, `:observer`, `:telemetry`, and tracing.
- Exposed via typed JSON over control channel (WebSocket / distributed Erlang port).
- Supports pause/resume of individual GenServers for surgical inspection.

### 3. Component 2: Simulation Universe (`Aether.Simulator` OTP app)
- Spins up isolated supervision trees mirroring production topology.
- Features:
  - Production trace replay (`:telemetry` or `:dbg`).
  - Fuzzing + counterfactual injection.
  - Shadow execution of proposed patches.
- Every simulation outputs structured data (state diffs, traces, invariant graphs, repair sequences) → logged to agent’s reinforcement buffer.
- Uses exact same BEAM bytecode as production.

### 4. Component 3: Human Interaction Layer
- Provenance graph (ETS or Mnesia): every change records generator, rationale, simulation results, human sign-off.
- Interactive review surface (LiveView or simple CLI):
  - NL summary of patch.
  - Diff, simulation results, before/after metrics.
  - “accept / reject / modify with rationale” buttons.
- Human feedback ingested back into agent’s training distribution.

### 5. Live Environment Features (Patching, Robustness, Resilience)

**Live Patching Flow** (zero-downtime):
1. AI proposes patch → custom compiler pass + invariant check.
2. Simulation pre-flight in `Aether.Simulator`.
3. Hot swap via `:code.load_file` / application upgrade (standard OTP).
4. Canary routing (`:pg` or load-balancer).
5. Live telemetry vs. invariants → auto-rollback on violation.

**Robustness Mechanisms** (declared in attributes):
- Self-healing hooks via `@recovery`.
- Background test oracle GenServer feeds failures to simulator.
- Lightweight guardian agents monitor mirrors and trigger autonomous repairs within safety bounds.

**Resilience Guarantees**:
- BEAM isolation + invariant proofs = no single patch can take down the node.
- Machine-centered REPL (`Aether.Reflect`) is the AI’s primary interface for full live-system comprehension.

### 6. Integration with Elixir Compilation Pipeline (Exact Points)
1. Source → Elixir AST (lexer + YECC).
2. Macro expansion (Aether macros run here).
3. **Aether compiler pass** (our custom `Mix.Tasks.Compile.Aether`).
4. Erlang Abstract Format → Core Erlang → BEAM bytecode (unchanged).

All extensions are **opt-in**; plain Elixir/OTP modules run unmodified.

### 7. MVP Implementation Checklist (for another LLM)
1. Implement `Aether` module + macros + `Aether.AgentBehaviour`.
2. Implement `Mix.Tasks.Compile.Aether` (minimal validation + metadata storage).
3. Implement `Aether.Reflect` (mirror API + registration).
4. Implement `Aether.Simulator` (basic isolated supervision tree + trace replay).
5. Add provenance ETS table + simple human review CLI.
6. Wire hot-patching path using standard OTP release handler + canary.
7. Write one end-to-end example (Payments service) demonstrating the full loop.
8. Add tests that exercise mirrors, simulation, and hot-swap.

**Constraints**
- Zero BEAM VM changes.
- No new syntax (only attributes + macros).
- Leverage existing gradual typing (v1.20+) for invariants where possible.
- Focus 100% on **live maintenance**; ignore green-field performance.

This spec is complete, self-contained, and ready for direct implementation. An
LLM can generate the full codebase from this document in one pass. Let me know
if you need the spec expanded with any single section or starter code skeletons.

## Practical Considerations

The condensed spec you have is the complete, minimal foundation.** It is
deliberately thin and leverages Elixir’s existing pipeline so that a competent
LLM (or human) can generate a working prototype from it in a single pass. The
extensions are all standard, battle-tested patterns (custom `Mix.Task.Compiler`,
hygienic macros, OTP apps, `:sys` introspection, release handlers).

However, to move from “spec” to “viable for real testing in practice” we need a
few pragmatic additions that make the system **immediately runnable**,
**observable**, **safe**, and **easy to iterate on**. These are not changes to
the core design — they are implementation guardrails and starter scaffolding.

### Practical Viability Addendum (add these to the spec)

#### 1. Packaging & Project Setup (so you can `mix deps.get` and test today)
Create Aether as a regular Hex package (or start as a local path dependency).

**Recommended directory layout for the Aether library itself:**
```
aether/
├── lib/
│   ├── aether.ex                  # macros + AgentBehaviour
│   ├── mix/tasks/compile/aether.ex # custom compiler
│   ├── aether/reflect.ex          # runtime mirrors (OTP app)
│   ├── aether/simulator.ex        # simulation harness (OTP app)
│   ├── aether/control.ex          # NEW: JSON control plane for LLM agent
│   └── aether/provenance.ex       # ETS/Mnesia graph
├── mix.exs
├── test/                          # end-to-end loop tests
└── README.md                      # exact “how to test the full cycle” instructions
```

In any test project’s `mix.exs`:
```elixir
defp deps do
  [
    {:aether, "~> 0.1.0"},          # or {:aether, path: "../aether"}
    {:jason, "~> 1.4"},             # for mirror JSON
    {:telemetry, "~> 1.0"}          # already in core, but explicit
  ]
end

def project do
  [
    compilers: Mix.compilers() ++ [:aether],
    ...
  ]
end
```

#### 2. Control Plane for the LLM Agent (`Aether.Control`)
The AI needs a single, typed entry point. Add this GenServer:

```elixir
defmodule Aether.Control do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def mirror(module_or_pid),      do: GenServer.call(__MODULE__, {:mirror, module_or_pid})
  def simulate(patch, trace_id),  do: GenServer.call(__MODULE__, {:simulate, patch, trace_id})
  def propose_patch(diff),        do: GenServer.call(__MODULE__, {:propose, diff})
  # etc.

  # Returns always JSON + NL summary for the LLM
  def handle_call({:mirror, target}, _from, state) do
    mirror = Aether.Reflect.mirror(target)
    {:reply, Jason.encode!(%{ok: mirror, summary: summarize(mirror)}), state}
  end
end
```

Start it in `application.ex` under the Aether supervision tree. The LLM agent now talks to one process over JSON (WebSocket, TCP, or even a simple HTTP endpoint if you expose it via Plug).

#### 3. Structured Diagnostics & Logging
Extend the custom compiler to always return `Mix.Task.Compiler.Diagnostic` structs with:
- `severity`, `message`, `file`, `position`
- Extra field `aether: %{confidence: 0.92, suggested_patch: "...", examples: [...]}`

Add `Aether.Logger` that emits Telemetry events for every step of the loop (detect → mirror → simulate → human_review → hot_swap → learn). This gives you a perfect trace for debugging the AI’s reasoning.

#### 4. Safety & Sandboxing (critical for live testing)
- Simulations always run in an isolated child supervision tree under `Aether.Simulator.Supervisor` with a separate node name or `:global` registry prefix.
- Registration of mirrors is **opt-in** (`use Aether` only on modules you want the AI to shepherd).
- Add a simple capability system: mirrors expose only whitelisted keys unless the calling process has `:aether_full_access`.

#### 5. MVP Test Project (one-command starter)
```bash
mix new test_aether --sup
cd test_aether
# edit mix.exs to add Aether as path dep
mix deps.get
mix aether.init   # (custom task that adds use Aether to a sample Payments GenServer)
```

Include in the starter:
- One GenServer with `@intent` / `@invariant` / `@recovery`.
- A tiny `test/live_loop_test.exs` that manually drives the full cycle (or lets you paste LLM output).

#### 6. Human Verification Stub
For early testing, ship a minimal CLI:
```elixir
Aether.HumanReview.prompt(patch)   # prints diff + simulation results, waits for "accept" / "reject" + rationale
```
Later replace with LiveView or Slack/Linear integration.

#### 7. Version Pinning & Dependencies (for reproducibility)
In `mix.exs` of Aether and all test projects:
```elixir
elixir: "~> 1.20.0-rc.4 or ~> 1.20",   # full type inference available
otp: ">= 27.0"
```
Dependencies: only `jason` + core OTP. No extra runtime deps.

#### 8. End-to-End Testing Instructions (in README)
1. Start `iex -S mix`
2. `Aether.Control.start_link([])`
3. Manually call `Aether.Control.mirror(Payments)` → see JSON mirror.
4. Simulate a failing invariant → run `Aether.Control.simulate(...)`
5. Propose a patch → see human review prompt.
6. Accept → watch hot-swap via `:observer` or logs.
7. Check provenance graph.

These eight additions turn the spec into something you can clone, compile, and start testing **today** with a real LLM agent (point the agent at the JSON control plane and give it the mirror schema).

The core spec was already 95 % of what is needed. These extras are the “production-readiness scaffolding” that make the difference between “theoretically correct” and “I can run the full observe-simulate-patch-verify loop in under 10 minutes.”

## Project Structure Sketch

**Here's a clean, practical starter repository structure for Aether.**

### Main Repository: `aether` (the library)

```
aether/
├── .gitignore
├── README.md                  # Full setup instructions + full-cycle demo
├── LICENSE
├── mix.exs
├── .formatter.exs
├── lib/
│   ├── aether.ex                     # Core macros + __using__ + AgentBehaviour
│   ├── mix/
│   │   └── tasks/
│   │       ├── compile/
│   │       │   └── aether.ex         # Custom Mix compiler pass
│   │       └── aether.init.ex        # Helper: mix aether.init
│   ├── aether/
│   │   ├── application.ex            # Starts Reflect + Simulator + Control
│   │   ├── control.ex                # JSON control plane GenServer for LLM
│   │   ├── reflect.ex                # Runtime mirrors
│   │   ├── simulator.ex              # Simulation harness
│   │   ├── provenance.ex             # ETS/Mnesia graph
│   │   ├── logger.ex                 # Telemetry events
│   │   └── human_review.ex           # CLI / stub for human verification
│   └── mix_aether.ex                 # Optional: extra Mix helpers
├── test/
│   ├── support/
│   │   └── payments.ex               # Sample GenServer for tests
│   ├── aether/
│   │   ├── compiler_test.exs
│   │   ├── reflect_test.exs
│   │   ├── simulator_test.exs
│   │   └── live_loop_test.exs        # End-to-end observe→simulate→patch test
│   └── test_helper.exs
├── config/
│   └── config.exs
└── examples/
    └── basic_payments/               # Small runnable example project
```

### Sample Test / Demo Project (`examples/basic_payments`)

When someone runs `mix aether.init`, it can scaffold this structure inside their own project:

```
basic_payments/
├── mix.exs
├── README.md
├── config/
│   └── config.exs
├── lib/
│   ├── basic_payments/
│   │   ├── application.ex
│   │   └── payments.ex               # Uses "use Aether"
│   └── basic_payments.ex
├── test/
│   └── live_shepherd_test.exs
└── .env                          # Optional for control plane port, etc.
```

---

### Key Files & Their Purpose (Quick Reference)

| File | Purpose |
|------|-------|
| `lib/aether.ex` | Macros, behaviours, `@intent`, `@invariant`, etc. |
| `lib/mix/tasks/compile/aether.ex` | The most important file — custom compiler pass |
| `lib/aether/control.ex` | Single JSON API the LLM agent talks to |
| `lib/aether/reflect.ex` | Live mirrors (`mirror/1`) |
| `lib/aether/simulator.ex` | Isolated simulation environment |
| `lib/aether/provenance.ex` | Immutable change history |
| `mix/tasks/aether.init.ex` | `mix aether.init` → adds Aether to any project |
| `test/live_loop_test.exs` | Manual or automated full shepherding loop test |

---

### Recommended `mix.exs` for the Aether library

```elixir
defmodule Aether.MixProject do
  use Mix.Project

  def project do
    [
      app: :aether,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:jason, "~> 1.4"},
        {:telemetry, "~> 1.0"}
      ],
      compilers: Mix.compilers() ++ [:aether]   # Important
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Aether.Application, []}
    ]
  end
end
```

---

### Next-Step Recommendations

1. Start with these files in order:
   - `aether.ex` (macros)
   - `compile/aether.ex` (compiler pass)
   - `reflect.ex` + `control.ex`
   - Then simulator and provenance

2. After the core is in place, run `mix aether.init` in the `examples/basic_payments` folder to test the full experience.

## Hardware Considerations for Local LLM Code Generation Model

We can absolutely turn Aether’s rich simulation data into a specialized local
LLM that excels at generating Aether/Elixir/OTP code.** The simulation universe
already produces exactly the high-signal data we need: structured mirrors (state
+ invariants + telemetry), trace replays, counterfactual executions, invariant
violations, repair sequences, provenance graphs, hot-patch diffs, and human
accept/reject rationales. This is gold for domain-specific
fine-tuning/distillation.

The architecture is a **two-tier system**:
- **Strong external LLM** (Claude 4, Grok 4, or Codex successor) — high-level
  reasoning, planning the shepherding loop, generating synthetic instruction
prompts, and evaluating proposals.
- **Local Aether-specialized model** — fast, private, cheap inference that
  implements the actual Elixir modules, patches, recovery hooks, etc., under the
external model’s instructions.

This keeps costs low and latency acceptable while giving the local model deep,
idiomatic understanding of Aether’s mirrors, invariants, live patching, and OTP
primitives.

### Infrastructure Plan (End-to-End)

1. **Training Data Pipeline (Automated, Ongoing)**
   - Run Aether’s `Aether.Simulator` in a loop (or during real live incidents).
   - For every simulation / live event, capture:
     - Before/after mirror JSON
     - Invariant violation + telemetry trace
     - Generated patch diff + provenance
     - Human review outcome + rationale
   - Feed this raw tuple to the external strong LLM with a prompt template:
     > “Given this Aether mirror state, invariant violation, and simulation
     > trace, generate a high-quality instruction-response pair for training an
     > Aether code generator. Instruction = natural-language task from the AI
     > shepherd. Response = complete, idiomatic Elixir module + patch that would
     > fix it.”
   - Output: thousands of clean `<instruction> … </instruction><response> …
     </response>` pairs (plus few-shot examples of correct Aether syntax).
   - Store in a simple SQLite/JSONL dataset that grows automatically. Aim for
     10k–50k high-quality pairs initially (easy to generate in a weekend of
     simulation runs).

2. **Distillation / Fine-Tuning Strategy**
   - **Base model** (chosen below) → continued pre-training or supervised
     fine-tuning on the synthetic dataset.
   - Technique: **LoRA / QLoRA** (or Unsloth for 2–3× faster training on
     consumer hardware). This is efficient — no full fine-tune needed.
   - Optional final step: **Knowledge distillation** from the strong external
     model (teacher) to the local model (student) using the same dataset +
teacher-generated logits.
   - Tools (2026 state-of-the-art, all local-friendly):
     - Axolotl or LLaMA-Factory (config-driven, excellent for code domains)
     - Unsloth (fastest on GPU/Apple Silicon)
     - MLX + mlx-lm (native for Apple Silicon, zero extra deps)
   - Training loop runs offline. After each batch of new Aether data, re-train
     incrementally (LoRA adapters are tiny, ~100–500 MB).

3. **Local Inference & Integration**
   - Serve the fine-tuned model via:
     - **Apple Silicon** → MLX + `mlx_lm` (or Ollama with MLX backend) → fastest
       on Mac.
     - **NVIDIA** → llama.cpp (GGUF) or vLLM (for batching) → exposed as
       OpenAI-compatible API.
   - Aether.Control GenServer already has the JSON control plane; simply route
     code-generation calls to `http://localhost:11434/v1/chat/completions` (or
MLX equivalent).
   - Prompt template for the local model:
     > “You are an expert Aether shepherd. Given this mirror + task from the
     > reasoning agent, output ONLY valid Aether/Elixir code + patch. Use
     > @intent, @invariant, @recovery exactly as trained.”

4. **Iteration & Safety**
   - After each real-world patch, add the outcome back into the dataset
     (positive or negative example).
   - Periodic human review of generated code keeps quality high.
   - Eval set: hold out 500 real Aether simulation cases and measure % of
     patches that pass invariants + compile + hot-swap successfully.

This pipeline is fully automated once the initial dataset and training script
are written. New simulation data continuously improves the local model.

### Model Recommendations (Realistic for Your Hardware)

**Primary recommendation: Qwen2.5-Coder series** (as of May 2026). It is
currently the strongest open-source coding model family for this exact use case
— excellent at instruction-following, long-context code editing, and Elixir-like
functional/OTP patterns. DeepSeek-Coder-V2-Lite is a close second (very
efficient MoE).

#### On M1 MacBook Pro (64 GB unified memory)
- **Best choice**: Qwen2.5-Coder-14B-Instruct (or 32B-Instruct if you accept
  slightly slower speed).
  - MLX 4-bit quantization: 14B fits in ~8–10 GB, 32B in ~18–22 GB.
  - Expected speed: 25–45 tokens/sec (14B) or 12–25 tokens/sec (32B) on M1/M2/M3
    Max.
  - Fine-tuning: Fully viable with Unsloth + MLX or Axolotl (LoRA on 14B uses
    <32 GB during training).
- Why it works: Apple Silicon + MLX loves these models. Real benchmarks show
  Qwen2.5-Coder-32B running comfortably on 64 GB Macs.

**Alternative smaller option** (if you want maximum speed):
Qwen2.5-Coder-7B-Instruct (4-bit, ~4 GB, 50+ tokens/sec).

#### On NVIDIA GeForce RTX 5060 (8 GB VRAM)
- **Best choice**: Qwen2.5-Coder-7B-Instruct or DeepSeek-Coder-V2-Lite-Instruct
  (16B total / 2.4B active MoE).
  - 4-bit / INT4 GGUF: both fit comfortably (5–7 GB total with KV cache for
    8k–16k context).
  - Expected speed: 40–80 tokens/sec on 7B; MoE makes the Lite version feel even
    faster.
- Fine-tuning: Possible with Unsloth or Axolotl + 4-bit QLoRA (8 GB is tight but
  doable for small batches). For comfort, do initial training on a rented cloud
GPU (see below) then run inference locally.

**RTX 5060 8 GB is viable for inference but marginal for comfortable
fine-tuning.** The newer GDDR7 memory helps, but 8 GB is the practical limit for
7B-class models with decent context.

### Hardware Upgrade Recommendations (If You Want Better Performance)

Your current hardware is already sufficient for a capable local Aether coder
(especially the Mac). For faster iteration and higher-quality 14B+ models:

- **Best Mac upgrade**: M4 Max or M5 Max with **128 GB unified memory** (or the
  new “Ultra” variant if available). This lets you run Qwen2.5-Coder-32B at
8-bit (or even lightly fine-tune 70B-class distilled models) at 30+ tokens/sec.
Cost: current M4 Max 128 GB configs are realistic for power users.

- **Best NVIDIA path**: Rent a cloud instance with **RTX 5090 (32 GB)** or
  **A100 40/80 GB / H100** on RunPod/Lambda/ Vast.ai (~$0.50–$2/hr). Do the
heavy LoRA fine-tuning there (one weekend = a few dollars), then download the
tiny adapter and run inference on your local 8 GB card or Mac. This is the most
practical way to get “frontier-level Aether understanding” without buying new
hardware.

**Bottom line**: You do **not** need new hardware to start today. A
Qwen2.5-Coder-14B (Mac) or 7B (RTX 5060) fine-tuned on your Aether simulation
data will already outperform a generic model by a wide margin on live patching,
mirror comprehension, and OTP idioms. The data pipeline + LoRA loop makes
continuous improvement free and automatic.


## LLM Training Script Sketch

**Here is a practical, ready-to-use training script sketch for your Aether-specialized local model.**

I recommend **Unsloth** as the primary tool because it works well on both your M1 MacBook Pro (via MLX backend or direct) and RTX 5060, offers 2–5× faster training with 60–70% less memory than standard Hugging Face, and has excellent support for Qwen2.5-Coder models.

### 1. Project Structure for Training

```
aether-training/
├── data/
│   ├── raw/                  # JSONL from simulator (mirror + trace + patch)
│   └── train/                # Processed instruction-response pairs
├── configs/
│   └── aether_lora.yml       # Axolotl-style or simple Unsloth script
├── scripts/
│   ├── generate_synthetic.py # External LLM → synthetic pairs
│   ├── train.py              # Main training script (below)
│   └── merge_and_quant.py    # Merge LoRA + export GGUF / MLX
├── dataset.jsonl
└── requirements.txt
```

### 2. Synthetic Data Generation (run periodically)

```python
# scripts/generate_synthetic.py
import json
from openai import OpenAI  # or Grok/Claude API client

client = OpenAI(base_url="http://localhost:11434/v1")  # or external API

def generate_pair(example):
    prompt = f"""You are training an Aether shepherd model.
Given this live system state and task, output ONLY valid Aether/Elixir code.

Mirror: {example['mirror']}
Task: {example['task']}
Invariant violation: {example['violation']}

Respond with:
<instruction>Clear natural language task</instruction>
<response>```elixir
# full module or patch using @intent, @invariant, @recovery etc.
```</response>"""

    resp = client.chat.completions.create(
        model="grok-4" or "claude-4",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7
    )
    # parse and save as Alpaca/ShareGPT format
```

### 3. Main Training Script (`scripts/train.py`)

```python
# scripts/train.py
from unsloth import FastLanguageModel
import torch
from datasets import load_dataset
from trl import SFTTrainer
from transformers import TrainingArguments

# ====================== CONFIG ======================
MODEL_NAME = "unsloth/Qwen2.5-Coder-14B-Instruct"   # or 7B for RTX 5060
MAX_SEQ_LENGTH = 16384                               # Aether mirrors + code fit well
DTYPE = torch.bfloat16 if torch.cuda.is_available() else None
LOAD_IN_4BIT = True

# Load model
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=MODEL_NAME,
    max_seq_length=MAX_SEQ_LENGTH,
    dtype=DTYPE,
    load_in_4bit=LOAD_IN_4BIT,
    trust_remote_code=True,
)

# Add LoRA adapters (very efficient)
model = FastLanguageModel.get_peft_model(
    model,
    r=32,                    # rank — good balance
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",  # saves huge VRAM
    random_state=3407,
    use_rslora=True,
    loftq_config=None,
)

# Load dataset (Alpaca/ShareGPT format)
dataset = load_dataset("json", data_files="dataset.jsonl", split="train")

def formatting_func(example):
    # Simple chat template for Qwen
    return tokenizer.apply_chat_template([
        {"role": "user", "content": example["instruction"]},
        {"role": "assistant", "content": example["response"]}
    ], tokenize=False, add_generation_prompt=False)

# Trainer
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field=None,  # we use formatting_func
    formatting_func=formatting_func,
    max_seq_length=MAX_SEQ_LENGTH,
    dataset_num_proc=4,
    packing=True,                    # packs multiple examples
    args=TrainingArguments(
        per_device_train_batch_size=2 if LOAD_IN_4BIT else 1,
        gradient_accumulation_steps=8,
        warmup_steps=10,
        max_steps=400,               # adjust based on dataset size
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=10,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir="outputs",
        report_to="none",            # or wandb
    ),
)

# Train
trainer.train()

# Save
model.save_pretrained("aether-shepherd-lora")
tokenizer.save_pretrained("aether-shepherd-lora")
```

**For Apple Silicon (MLX native alternative)** — replace the above with `mlx-lm` + LoRA:

```bash
pip install mlx-lm
mlx_lm.lora --model Qwen/Qwen2.5-Coder-14B-Instruct \
            --train \
            --data dataset.jsonl \
            --iters 400 \
            --batch-size 4 \
            --lora-rank 32
```

### 4. Merge, Quantize & Export

```python
# scripts/merge_and_quant.py
from unsloth import FastLanguageModel
model, tokenizer = FastLanguageModel.from_pretrained("aether-shepherd-lora")
model = FastLanguageModel.for_inference(model)   # merge LoRA

# Export to GGUF (for llama.cpp / Ollama)
model.save_pretrained_gguf("aether-shepherd-gguf", tokenizer, quantization_method="q4_k_m")

# Or for MLX on Mac
# mlx_lm.convert --model aether-shepherd-lora --quantize
```

### 5. Serving

- **NVIDIA**: `ollama run aether-shepherd` or vLLM.
- **Mac**: `mlx_lm.server` or Ollama with MLX backend.
- Point `Aether.Control` to `http://localhost:11434/v1`.

### 6. Continuous Training Loop (Recommended)

Run a daily/weekly cron that:
1. Collects new simulation data.
2. Generates 500–2000 new synthetic pairs using the strong external model.
3. Runs incremental LoRA training (only 50–100 steps).
4. Merges and replaces the serving model.

This keeps your local shepherd continuously improving with real Aether live-system knowledge.

## Docker Setup Sketch

### 1. Synthetic Prompt Template  
(`scripts/generate_synthetic.py`)

```python
# scripts/generate_synthetic.py
import json
from openai import OpenAI   # or anthropic / xAI client

client = OpenAI(base_url="https://api.grok.x.ai/v1")   # or Claude, etc.

PROMPT_TEMPLATE = """You are an expert Aether shepherd trainer.

You will be given:
- A live runtime mirror (structured JSON)
- The current task / invariant violation
- A short simulation trace

Your job is to produce ONE high-quality training example for the local Aether model.

Output EXACTLY this format (nothing else):

<instruction>
Clear, natural-language task that the strong reasoning model would give to the local coder.
Example: "The payments GenServer just violated the idempotency invariant under high load. Fix it using @recovery and @invariant while keeping the system live."
</instruction>

<response>
```elixir
# Full, idiomatic Aether/Elixir code or hot-patch
# Must use @intent, @invariant, @recovery, @on_failure exactly as trained
defmodule Payments do
  use Aether
  @intent "..."
  @invariant [...]
  @recovery "..."
  # ... actual fix
end
```
</response>

Mirror:
{mirror}

Task:
{task}

Invariant violation:
{violation}

Simulation trace summary:
{trace}
"""

def generate_pair(example: dict) -> dict:
    prompt = PROMPT_TEMPLATE.format(
        mirror=json.dumps(example["mirror"], indent=2),
        task=example["task"],
        violation=example["violation"],
        trace=example.get("trace_summary", "N/A")
    )
    
    resp = client.chat.completions.create(
        model="grok-4",           # or claude-4-sonnet
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
        max_tokens=2048
    )
    
    # Parse the <instruction> and <response> tags
    text = resp.choices[0].message.content
    # (simple regex or string split to extract the two fields)
    return {"instruction": ..., "response": ...}
```

Run this periodically after every simulation run to grow your dataset.

### 2. Axolotl YAML Config  
(`configs/aether_lora.yml`)

```yaml
# configs/aether_lora.yml
base_model: Qwen/Qwen2.5-Coder-14B-Instruct     # change to 7B for RTX 5060
model_type: Qwen2

chat_template: qwen   # official Qwen chat template

datasets:
  - path: dataset.jsonl
    type: sharegpt
    conversation: "chatml"   # works great with Qwen

dataset_prepared_path: ./cache/aether_prepared

output_dir: ./outputs/aether-shepherd-14b-lora

sequence_len: 16384
sample_packing: true
pad_to_sequence_len: true

adapter: lora
lora_r: 32
lora_alpha: 16
lora_dropout: 0.05
lora_target_linear: true

load_in_8bit: false
load_in_4bit: true
strict: false

gradient_checkpointing: true
gradient_accumulation_steps: 8

batch_size: 2
micro_batch_size: 1
num_epochs: 3

optimizer: adamw_bnb_8bit
lr: 2.0e-4
lr_scheduler: cosine
warmup_steps: 100

logging_steps: 10
save_steps: 200
eval_steps: 200

wandb_project: null
report_to: null

# Cloud / hardware friendly settings
bf16: auto
fp16: auto
tf32: false

# For rented GPUs (RunPod / Vast.ai) you can increase these
# For local RTX 5060 8GB keep micro_batch_size=1
```

**How to train:**
```bash
axolotl train configs/aether_lora.yml
```

For incremental training just point it at the latest `dataset.jsonl` — Axolotl supports continuing from a previous LoRA checkpoint.

### 3. Dockerfile (works locally + transparently on rented cloud GPUs)

```dockerfile
# Dockerfile
FROM ghcr.io/axolotl-ai-cloud/axolotl:main-latest

# Optional: for Apple Silicon you would use a different base, but this one is perfect for cloud GPUs

RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy training assets
COPY configs/aether_lora.yml /workspace/configs/aether_lora.yml
COPY dataset.jsonl /workspace/dataset.jsonl
COPY scripts/ /workspace/scripts/

# Install extra deps if needed
RUN pip install --no-cache-dir jinja2

# Default command runs training
CMD ["accelerate", "launch", "-m", "axolotl.cli.train", "configs/aether_lora.yml"]
```

**Usage**

**Local (your RTX 5060 or Mac):**
```bash
docker build -t aether-trainer .
docker run --gpus all --rm -it -v $(pwd):/workspace aether-trainer
```

**Rented cloud GPU (RunPod / Vast.ai / Lambda — fully transparent):**
1. Create a pod with any CUDA 12.4+ image (e.g. RunPod’s “Axolotl” community template or “PyTorch 2.4”).
2. `git clone` your repo into the pod.
3. Run the exact same `docker build` + `docker run` commands above (the container will see the attached GPU automatically).
4. After training finishes, `docker cp` the `outputs/aether-shepherd-14b-lora` folder back to your machine (or push to Hugging Face).

Typical cost on a strong rented GPU (A100 40GB or H100): ~$0.80–$1.50/hour. A full 400-step LoRA run takes 2–4 hours → total cost <$6.

**After training** use the `merge_and_quant.py` script (from previous message) to produce a GGUF/MLX version for local inference.










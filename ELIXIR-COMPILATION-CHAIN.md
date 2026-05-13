**The Elixir compilation chain is a multi-stage pipeline that transforms human-readable Elixir source code (.ex or .exs files) into BEAM bytecode—the executable format that runs on the Erlang Virtual Machine (BEAM).** OTP itself does not introduce separate “OTP bytecode”; OTP is a set of libraries, behaviours (GenServer, Supervisor, etc.), and runtime conventions built on top of Erlang/Elixir. All Elixir (and Erlang) code ultimately compiles to the same BEAM bytecode that the OTP runtime loads and executes.

Elixir does **not** generate Erlang source code (.erl files) as an intermediate step. Instead, it produces Erlang’s internal abstract representations and hands them directly to the Erlang compiler. The process is the same whether you run `mix compile`, `elixirc`, or the `elixir` command on a script—only the output (disk files vs. in-memory execution) differs.

Here is the detailed end-to-end chain:

### 1. Source Loading & Parsing → Elixir AST
- The file contents are loaded into memory.
- A custom lexer (`elixir_tokenizer.erl`) tokenizes the source.
- The YECC parser (an Erlang parser generator) turns the tokens into an **Elixir Abstract Syntax Tree (AST)**.
  - The AST is represented as ordinary Elixir terms (nested tuples/lists with atoms like `{:def, meta, ...}`).
  - This is the same structure you see when you call `quote do: ... end` or `Macro.to_string/1`.

**Example** (simplified):
```elixir
# Source
defmodule Foo do
  def bar(x), do: x + 1
end
```
becomes something like:
```elixir
{:defmodule, [...], [{:__aliases__, ..., [:Foo]}, [do: {:def, ..., ...}]]}
```

### 2. Macro Expansion & Transformations → Expanded Elixir AST
- The Elixir compiler walks the AST and expands all macros (built-in and user-defined).
- This includes `def`, `defmacro`, `use`, `require`, `import`, attribute handling (`@moduledoc`, `@behaviour`, etc.), and hygiene transformations.
- Other compiler passes also run: inlining, constant evaluation, etc.
- The result is a **fully expanded Elixir AST** that still follows the same quoted-expression format but contains no unexpanded macros.

This phase is where most Elixir-specific “magic” happens and is why Elixir feels so extensible.

### 3. Elixir Compiler → Erlang Abstract Format (AbsForm / EAF)
- The expanded Elixir AST is converted into **Erlang Abstract Format** (also called “forms” or EAF).
- This is a standard Erlang data structure: a list of Erlang terms that represent the module, functions, attributes, etc., exactly as the Erlang compiler expects (see `:erl_parse` and `absform` docs).
- Elixir’s compiler (implemented mostly in Erlang under `lib/elixir/src/`) performs this translation using functions such as `:elixir.quoted_to_erl/2`.

At this point, Elixir’s work is essentially done. The rest of the pipeline is the Erlang compiler.

### 4. Erlang Compiler Pipeline
The Erlang compiler (`:compile` module) takes the abstract forms and runs them through several internal passes:

| Stage                  | Description                                                                 | How to inspect (Erlang)                  |
|------------------------|-----------------------------------------------------------------------------|------------------------------------------|
| **Abstract Syntax Tree (‘P’)** | Raw parsed forms                                                            | `c(file, 'P')`                           |
| **Expanded AST (‘E’)** | After parse transforms                                                      | `c(file, 'E')`                           |
| **Core Erlang**        | High-level functional intermediate representation (most optimizations here) | `c(file, to_core)`                       |
| **Kernel Erlang**      | Flattened, lambda-lifted, pattern-matching compiled                        | `c(file, to_kernel)`                     |
| **Life analysis**      | Variable lifetime analysis                                                  | (internal “life” pass)                   |
| **BEAM Bytecode**      | Final linear instructions for the BEAM VM                                   | `c(file, 'S')` or `:beam_disasm.file/1` |

- **Core Erlang** is the most important intermediate form; it is where the bulk of optimizations (inlining, dead-code elimination, etc.) occur.
- The final output of `:compile.forms/2` (or `:compile.file/2`) is a binary containing the BEAM bytecode plus metadata (debug info, exports, attributes, etc.).

### 5. Output & Loading
- **elixirc / Mix compile**: The BEAM binary is written to disk as `ModuleName.beam` (named after the module, not the source file).
- **elixir (script mode)**: The binary is kept in memory, loaded via the Erlang code server (`:code.load_binary/3`), and executed by calling a synthetic wrapper function `elixir_compiler_N.__FILE__/1` that contains the entire program body.
- The BEAM VM then loads the module into its code server, making functions available for OTP supervisors, GenServers, etc.

### Parallel Compilation (Mix / Kernel.ParallelCompiler)
In a real project, `mix compile` uses `Kernel.ParallelCompiler`. It spawns one Erlang process per file, compiles them concurrently, and resolves inter-file dependencies on-the-fly using a custom error handler that pauses compilation when an undefined module is referenced and resumes once the dependency is ready.

### Summary of the Full Chain
Elixir source  
→ **Parse** → Elixir AST  
→ **Macro expansion** → Expanded Elixir AST  
→ **Elixir compiler** → Erlang Abstract Format (EAF)  
→ **Erlang compiler** → Core Erlang → Kernel Erlang → **BEAM bytecode** (.beam file or in-memory binary)  
→ Loaded by BEAM VM → Executed by OTP runtime

This design is why Elixir interoperates seamlessly with Erlang, inherits OTP’s hot-code swapping and supervision, and why extending Elixir (as discussed in our earlier AetherLang vision) is relatively straightforward: you work at the AST/macro level or add compiler plugins that hook into the same pipeline before the Erlang Abstract Format step. The resulting .beam files are indistinguishable from hand-written Erlang ones.


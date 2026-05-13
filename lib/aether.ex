defmodule Aether do
  @moduledoc """
  Thin Elixir extensions for Aether metadata, mirrors, simulation, and provenance.
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :intent, persist: true)
      Module.register_attribute(__MODULE__, :invariant, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :recovery, persist: true)
      Module.register_attribute(__MODULE__, :on_failure, persist: true)

      @before_compile Aether
      @after_compile {Aether, :__after_compile__}
    end
  end

  defmacro __before_compile__(env) do
    metadata = Aether.Metadata.build(env.module, metadata_source(env))

    quote do
      @doc false
      def __aether__ do
        unquote(Macro.escape(metadata))
      end
    end
  end

  def __after_compile__(env, _bytecode) do
    apply(env.module, :__aether__, [])
    |> Aether.Metadata.store()

    :ok
  end

  defp metadata_source(env) do
    %{
      intent: Module.get_attribute(env.module, :intent),
      invariants: Module.get_attribute(env.module, :invariant) |> List.wrap(),
      recovery: Module.get_attribute(env.module, :recovery),
      on_failure: Module.get_attribute(env.module, :on_failure),
      file: env.file,
      line: env.line,
      source_location: %{file: env.file, line: env.line}
    }
  end
end

defmodule Aether.Metadata do
  @moduledoc """
  Normalizes, validates, and persists Aether metadata.
  """

  alias Aether.Invariant

  defstruct [
    :module,
    :intent,
    :invariants,
    :recovery,
    :on_failure,
    :schema_version,
    :source_digest,
    :source_location,
    :artifact_path,
    :captured_at
  ]

  @schema_version 1

  def build(module, attrs) do
    source_location = attrs[:source_location] || %{file: nil, line: nil}

    invariants =
      attrs[:invariants]
      |> List.wrap()
      |> Enum.map(&Invariant.normalize(&1, module, source_location))

    source_digest = source_digest(attrs[:file], attrs)

    %__MODULE__{
      module: module,
      intent: attrs[:intent],
      invariants: invariants,
      recovery: attrs[:recovery],
      on_failure: attrs[:on_failure],
      schema_version: @schema_version,
      source_digest: source_digest,
      source_location: source_location,
      artifact_path: artifact_path(module, source_digest),
      captured_at: DateTime.utc_now()
    }
    |> validate!()
  end

  def validate!(%__MODULE__{} = metadata) do
    cond do
      metadata.intent != nil and not is_binary(metadata.intent) and not is_map(metadata.intent) ->
        raise ArgumentError, "intent must be nil, a string, or a structured map"

      not is_list(metadata.invariants) ->
        raise ArgumentError, "invariants must be a list"

      true ->
        metadata
    end
  end

  def store(%__MODULE__{} = metadata) do
    Aether.Storage.put(Aether.Storage.metadata_table(), metadata.module, metadata)
    persist_artifact(metadata)
    metadata
  end

  def lookup(module) when is_atom(module) do
    case Aether.Storage.fetch(Aether.Storage.metadata_table(), module) do
      {:ok, metadata} -> {:ok, metadata}
      :error -> :error
    end
  end

  def source_digest(file, attrs) do
    payload =
      case file do
        nil ->
          inspect(attrs, limit: :infinity, pretty: false, charlists: :as_lists)

        file ->
          case File.read(file) do
            {:ok, contents} -> contents
            {:error, _} -> inspect(attrs, limit: :infinity, pretty: false, charlists: :as_lists)
          end
      end

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
  end

  def artifact_path(module, digest) do
    Aether.Storage.metadata_path(module, digest)
  end

  defp persist_artifact(%__MODULE__{} = metadata) do
    path = metadata.artifact_path
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      inspect(metadata, pretty: true, limit: :infinity, width: 120, charlists: :as_lists) <> "\n"
    )
  end
end

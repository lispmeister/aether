defmodule Aether.Provenance do
  @moduledoc """
  Append-only provenance records for proposals, reviews, and simulations.
  """

  defmodule Record do
    @moduledoc false
    defstruct [
      :proposal_id,
      :module,
      :source_digest,
      :trace_id,
      :simulation_id,
      :generated_by,
      :reviewer,
      :decision,
      :timestamp,
      :rationale,
      :artifact_hash
    ]
  end

  def append(%Record{} = record) do
    record = normalize_record(record)
    Aether.Storage.append_record(Aether.Storage.provenance_table(), record)
    persist(record)
    record
  end

  def list do
    Aether.Storage.records(Aether.Storage.provenance_table())
    |> Enum.sort_by(&DateTime.to_unix(&1.timestamp, :microsecond))
  end

  def review_record(packet, decision, rationale) do
    %Record{
      proposal_id: Map.get(packet, :proposal_id),
      module: Map.get(packet, :module),
      source_digest: Map.get(packet, :source_digest),
      trace_id: Map.get(packet, :trace_id),
      simulation_id: Map.get(packet, :simulation_id),
      generated_by: Map.get(packet, :generated_by),
      reviewer: Map.get(packet, :reviewer),
      decision: decision,
      timestamp: DateTime.utc_now(),
      rationale: rationale,
      artifact_hash: Map.get(packet, :artifact_hash)
    }
    |> append()
  end

  defp normalize_record(%Record{} = record) do
    %{record | timestamp: record.timestamp || DateTime.utc_now()}
  end

  defp persist(%Record{} = record) do
    path = Aether.Storage.provenance_path()
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      inspect(record, pretty: true, limit: :infinity, width: 120, charlists: :as_lists) <> "\n",
      [:append]
    )
  end
end

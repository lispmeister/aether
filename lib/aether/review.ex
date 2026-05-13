defmodule Aether.Review do
  @moduledoc """
  Human review packets for proposed changes.
  """

  defmodule Packet do
    @moduledoc false
    defstruct [
      :proposal_id,
      :module,
      :source_digest,
      :intent,
      :invariants,
      :mirror,
      :simulation,
      :generated_by,
      :reviewer,
      :patch_diff,
      :rollout_recommendation,
      :artifact_hash,
      :trace_id,
      :simulation_id
    ]
  end

  def packet(metadata, mirror, simulation, opts \\ []) do
    %Packet{
      proposal_id: Keyword.get(opts, :proposal_id, proposal_id(metadata)),
      module: metadata.module,
      source_digest: metadata.source_digest,
      intent: metadata.intent,
      invariants: metadata.invariants,
      mirror: mirror,
      simulation: simulation,
      generated_by: Keyword.get(opts, :generated_by, "aether"),
      reviewer: Keyword.get(opts, :reviewer),
      patch_diff: Keyword.get(opts, :patch_diff),
      rollout_recommendation: rollout_recommendation(simulation),
      artifact_hash:
        Keyword.get(opts, :artifact_hash, artifact_hash(metadata, mirror, simulation)),
      trace_id: Keyword.get(opts, :trace_id),
      simulation_id: Keyword.get(opts, :simulation_id)
    }
  end

  def summary(%Packet{} = packet) do
    [
      "module=#{inspect(packet.module)}",
      "invariants=#{length(List.wrap(packet.invariants))}",
      "simulation=#{inspect(simulation_status(packet.simulation))}",
      "recommendation=#{packet.rollout_recommendation}"
    ]
    |> Enum.join(" ")
  end

  defp proposal_id(metadata) do
    digest =
      :crypto.hash(:sha256, inspect({metadata.module, metadata.source_digest, metadata.intent}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "proposal_#{digest}"
  end

  defp rollout_recommendation(%{status: :ok}), do: :proceed
  defp rollout_recommendation(%{status: :warning}), do: :review
  defp rollout_recommendation(%{status: status}), do: status
  defp rollout_recommendation(_), do: :unknown

  defp artifact_hash(metadata, mirror, simulation) do
    :crypto.hash(
      :sha256,
      inspect({metadata, mirror, simulation},
        limit: :infinity,
        pretty: false,
        charlists: :as_lists
      )
    )
    |> Base.encode16(case: :lower)
  end

  defp simulation_status(%{status: status}), do: status
  defp simulation_status(_), do: :unknown
end

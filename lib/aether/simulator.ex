defmodule Aether.Simulator do
  @moduledoc """
  Deterministic replay of trace-like events in an isolated process.
  """

  defmodule Run do
    @moduledoc false
    defstruct [
      :module,
      :trace,
      :initial_state,
      :final_state,
      :states,
      :diffs,
      :invariant_deltas,
      :replay_logs,
      :failure_classification,
      :rollout_recommendation,
      :status
    ]
  end

  def replay(module, trace) when is_atom(module) and is_list(trace) do
    Task.async(fn -> replay_in_process(module, trace) end)
    |> Task.await(:timer.seconds(5))
  end

  def replay(module, trace, opts) when is_atom(module) and is_list(trace) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, :timer.seconds(5))

    Task.async(fn -> replay_in_process(module, trace) end)
    |> Task.await(timeout)
  end

  defp replay_in_process(module, trace) do
    initial_state = module.initial_state()

    {states, diffs, logs, final_state, classification} =
      Enum.reduce_while(trace, {[initial_state], [], [], initial_state, :ok}, fn event,
                                                                                 {states, diffs,
                                                                                  logs, state,
                                                                                  classification} ->
        try do
          next_state = module.apply_event(state, event)
          diff = state_diff(state, next_state)

          {:cont,
           {
             [next_state | states],
             [%{event: event, diff: diff} | diffs],
             [%{event: event, status: :ok} | logs],
             next_state,
             classification
           }}
        rescue
          exception ->
            {:halt,
             {
               states,
               diffs,
               [%{event: event, status: :error, error: Exception.message(exception)} | logs],
               state,
               {:error, exception}
             }}
        end
      end)

    states = Enum.reverse(states)
    diffs = Enum.reverse(diffs)
    logs = Enum.reverse(logs)
    status = if classification == :ok, do: :ok, else: :error

    %Run{
      module: module,
      trace: trace,
      initial_state: initial_state,
      final_state: final_state,
      states: states,
      diffs: diffs,
      invariant_deltas: [],
      replay_logs: logs,
      failure_classification: classification,
      rollout_recommendation: rollout_recommendation(status),
      status: status
    }
  end

  defp rollout_recommendation(:ok), do: :proceed
  defp rollout_recommendation(:error), do: :hold

  defp state_diff(%{} = before, %{} = after_state) do
    %{
      added: Map.drop(after_state, Map.keys(before)),
      removed: Map.drop(before, Map.keys(after_state)),
      changed: changed_keys(before, after_state)
    }
  end

  defp state_diff(before, after_state), do: %{before: before, after: after_state}

  defp changed_keys(before, after_state) do
    Map.keys(before)
    |> Enum.filter(fn key -> Map.get(before, key) != Map.get(after_state, key) end)
  end
end

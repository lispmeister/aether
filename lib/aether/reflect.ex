defmodule Aether.Reflect do
  @moduledoc """
  Read-only runtime snapshots for modules and registered processes.
  """

  def register(pid, module, opts \\ [])

  def register(pid, module, opts) when is_pid(pid) and is_atom(module) and is_list(opts) do
    Aether.Storage.put(Aether.Storage.reflect_table(), pid, %{module: module, opts: opts})
    :ok
  end

  def unregister(pid) when is_pid(pid) do
    Aether.Storage.delete(Aether.Storage.reflect_table(), pid)
    :ok
  end

  def mirror(target) when is_atom(target) do
    cond do
      function_exported?(target, :__aether__, 0) ->
        mirror_module(target)

      is_pid(Process.whereis(target)) ->
        mirror(Process.whereis(target))

      true ->
        %{
          subject: target,
          version: 1,
          state: nil,
          invariants: [],
          telemetry: %{},
          history: %{},
          actors: %{},
          redactions: []
        }
    end
  end

  def mirror(pid) when is_pid(pid) do
    registration =
      case Aether.Storage.fetch(Aether.Storage.reflect_table(), pid) do
        {:ok, reg} -> reg
        :error -> %{module: nil, opts: []}
      end

    state =
      case safe_sys_get_state(pid) do
        {:ok, value} -> redact(value, registration.opts)
        :error -> nil
      end

    %{
      subject: pid,
      version: 1,
      state: state,
      invariants: invariants_for(registration.module),
      telemetry: %{},
      history: %{},
      actors: %{},
      redactions: redaction_report(state)
    }
  end

  def mirror({:registered, name}) when is_atom(name) do
    case Process.whereis(name) do
      nil ->
        %{
          subject: name,
          version: 1,
          state: nil,
          invariants: [],
          telemetry: %{},
          history: %{},
          actors: %{},
          redactions: []
        }

      pid ->
        mirror(pid)
    end
  end

  defp mirror_module(module) do
    metadata = module.__aether__()

    %{
      subject: module,
      version: metadata.schema_version,
      state: nil,
      intent: metadata.intent,
      invariants: metadata.invariants,
      recovery: metadata.recovery,
      on_failure: metadata.on_failure,
      telemetry: %{},
      history: %{},
      actors: %{},
      redactions: []
    }
  end

  defp invariants_for(nil), do: []

  defp invariants_for(module) do
    case Aether.Metadata.lookup(module) do
      {:ok, metadata} -> metadata.invariants
      :error -> []
    end
  end

  defp safe_sys_get_state(pid) do
    try do
      {:ok, :sys.get_state(pid)}
    catch
      :exit, _ -> :error
    end
  end

  defp redact(value, opts) do
    keys =
      Keyword.get(opts, :redact_keys, [
        :password,
        :secret,
        :token,
        :api_key,
        "password",
        "secret",
        "token",
        "api_key"
      ])

    redact_value(value, keys)
  end

  defp redact_value(%{} = map, keys) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if key in keys do
        Map.put(acc, key, "[REDACTED]")
      else
        Map.put(acc, key, redact_value(value, keys))
      end
    end)
  end

  defp redact_value(list, keys) when is_list(list), do: Enum.map(list, &redact_value(&1, keys))
  defp redact_value(other, _keys), do: other

  defp redaction_report(nil), do: []
  defp redaction_report(value), do: collect_redactions(value, [])

  defp collect_redactions(%{} = map, acc) do
    Enum.reduce(map, acc, fn {key, value}, acc ->
      if value == "[REDACTED]" do
        [%{field: key, reason: "secret"} | acc]
      else
        collect_redactions(value, acc)
      end
    end)
  end

  defp collect_redactions(list, acc) when is_list(list),
    do: Enum.reduce(list, acc, &collect_redactions/2)

  defp collect_redactions(_, acc), do: acc
end

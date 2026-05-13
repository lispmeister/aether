defmodule Aether.Storage do
  @moduledoc false

  @metadata_table :aether_metadata
  @provenance_table :aether_provenance
  @reflect_table :aether_reflect_registry

  def metadata_table, do: @metadata_table
  def provenance_table, do: @provenance_table
  def reflect_table, do: @reflect_table

  def put(table, key, value) do
    ensure_table(table)
    :ets.insert(table, {key, value})
    :persistent_term.put({table, key}, value)
    :ok
  end

  def fetch(table, key) do
    case :persistent_term.get({table, key}, :error) do
      :error ->
        case :ets.lookup(ensure_table(table), key) do
          [{^key, value}] -> {:ok, value}
          [] -> :error
        end

      value ->
        {:ok, value}
    end
  end

  def append_record(table, value) do
    ensure_table(table)
    key = {System.unique_integer([:monotonic, :positive]), System.system_time(:microsecond)}
    :ets.insert(table, {key, value})

    existing = :persistent_term.get({table, :records}, [])
    :persistent_term.put({table, :records}, [value | existing])
    :ok
  end

  def records(table) do
    case :persistent_term.get({table, :records}, :error) do
      :error ->
        ensure_table(table)
        |> :ets.tab2list()
        |> Enum.map(fn {_key, value} -> value end)

      records ->
        Enum.reverse(records)
    end
  end

  def list(table) do
    records(table)
  end

  def delete(table, key) do
    :ets.delete(ensure_table(table), key)
    :persistent_term.erase({table, key})
    :ok
  end

  def metadata_path(module, digest) do
    module_name =
      module
      |> Module.split()
      |> Enum.join(".")

    Path.join([build_root(), "aether", "metadata", "#{module_name}-#{digest}.term"])
  end

  def provenance_path do
    Path.join([build_root(), "aether", "provenance.log"])
  end

  def build_root do
    try do
      Mix.Project.build_path()
    rescue
      _ -> Path.expand("_build")
    end
  end

  defp ensure_table(table) when is_atom(table) do
    case :ets.whereis(table) do
      :undefined ->
        :ets.new(table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      tid ->
        tid
    end
  end
end

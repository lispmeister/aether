defmodule Aether.Invariant do
  @moduledoc """
  Structured invariant representation and normalization.
  """

  defstruct [
    :id,
    :expression,
    :scope,
    :severity,
    :source_location,
    :status,
    :last_checked_at
  ]

  @allowed_severities [:debug, :info, :warning, :critical]
  @allowed_statuses [:pending, :ok, :violated, :unknown]

  def normalize(value, module, source_location) do
    case value do
      %__MODULE__{} = invariant ->
        validate!(invariant)

      value when is_map(value) ->
        value
        |> build_from_map(module, source_location)
        |> validate!()

      value ->
        %__MODULE__{
          id: stable_id(module, value),
          expression: to_expression(value),
          scope: :module,
          severity: :warning,
          source_location: source_location,
          status: :pending,
          last_checked_at: nil
        }
        |> validate!()
    end
  end

  def validate!(%__MODULE__{} = invariant) do
    cond do
      not is_binary(invariant.id) or invariant.id == "" ->
        raise ArgumentError, "invariant id must be a non-empty string"

      not is_binary(invariant.expression) or invariant.expression == "" ->
        raise ArgumentError, "invariant expression must be a non-empty string"

      invariant.scope not in [:module, :function, :process] and not is_binary(invariant.scope) ->
        raise ArgumentError,
              "invariant scope must be one of :module, :function, :process, or a string"

      invariant.severity not in @allowed_severities ->
        raise ArgumentError, "invariant severity must be one of #{inspect(@allowed_severities)}"

      invariant.status not in @allowed_statuses ->
        raise ArgumentError, "invariant status must be one of #{inspect(@allowed_statuses)}"

      not valid_source_location?(invariant.source_location) ->
        raise ArgumentError,
              "invariant source_location must be a map or keyword with file and line"

      true ->
        invariant
    end
  end

  defp build_from_map(value, module, source_location) do
    %__MODULE__{
      id: normalize_id(Map.get(value, :id), module, Map.get(value, :expression, value)),
      expression: Map.get(value, :expression, to_expression(value)),
      scope: Map.get(value, :scope, :module),
      severity: Map.get(value, :severity, :warning),
      source_location: Map.get(value, :source_location, source_location),
      status: Map.get(value, :status, :pending),
      last_checked_at: Map.get(value, :last_checked_at)
    }
  end

  defp stable_id(module, value) do
    digest =
      :crypto.hash(:sha256, "#{inspect(module)}:#{to_expression(value)}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "inv_#{digest}"
  end

  defp normalize_id(nil, module, expression), do: stable_id(module, expression)
  defp normalize_id(id, _module, _expression) when is_binary(id) and id != "", do: id
  defp normalize_id(id, _module, _expression), do: to_string(id)

  defp to_expression(value) when is_binary(value), do: value

  defp to_expression(value),
    do: inspect(value, limit: :infinity, pretty: false, charlists: :as_lists)

  defp valid_source_location?(nil), do: true
  defp valid_source_location?(%{file: file, line: line}), do: is_binary(file) and is_integer(line)

  defp valid_source_location?(keyword) when is_list(keyword),
    do: Keyword.has_key?(keyword, :file) and Keyword.has_key?(keyword, :line)

  defp valid_source_location?(_), do: false
end

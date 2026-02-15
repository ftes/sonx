defprotocol Sonx.Evaluatable do
  @moduledoc """
  Protocol for items that can be evaluated against metadata (Ternary and Literal).
  """

  @doc "Evaluates the item against the given metadata."
  @spec evaluate(t(), Sonx.ChordSheet.Metadata.t(), String.t()) :: String.t()
  def evaluate(item, metadata, separator \\ ", ")
end

defimpl Sonx.Evaluatable, for: Sonx.ChordSheet.Literal do
  def evaluate(%{string: string}, _metadata, _separator), do: string
end

defimpl Sonx.Evaluatable, for: Sonx.ChordSheet.Ternary do
  alias Sonx.ChordSheet.{Literal, Metadata, Ternary}

  def evaluate(%Ternary{variable: nil}, _metadata, _separator) do
    ""
  end

  def evaluate(%Ternary{} = ternary, metadata, separator) do
    value = Metadata.get(metadata, ternary.variable)

    if value != nil and (ternary.value_test == nil or value == ternary.value_test) do
      evaluate_truthy(ternary, metadata, separator, value)
    else
      evaluate_expressions(ternary.false_expression, metadata, separator)
    end
  end

  defp evaluate_truthy(ternary, metadata, separator, value) do
    if ternary.true_expression == [] do
      value_to_string(value, separator)
    else
      evaluate_expressions(ternary.true_expression, metadata, separator)
    end
  end

  defp evaluate_expressions([], _metadata, _separator), do: ""

  defp evaluate_expressions(expressions, metadata, separator) do
    Enum.map_join(expressions, "", fn
      %Ternary{} = t -> Sonx.Evaluatable.evaluate(t, metadata, separator)
      %Literal{} = l -> Sonx.Evaluatable.evaluate(l, metadata, separator)
    end)
  end

  defp value_to_string(value, separator) when is_list(value), do: Enum.join(value, separator)
  defp value_to_string(value, _separator) when is_binary(value), do: value
  defp value_to_string(_, _), do: ""
end

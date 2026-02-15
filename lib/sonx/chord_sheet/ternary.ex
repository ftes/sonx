defmodule Sonx.ChordSheet.Ternary do
  @moduledoc """
  Represents a ChordPro meta expression: `%{variable|trueExpr|falseExpr}`.

  Used for conditional content based on metadata values.
  """

  use TypedStruct

  alias Sonx.ChordSheet.Literal

  typedstruct do
    field(:variable, String.t() | nil, default: nil)
    field(:value_test, String.t() | nil, default: nil)
    field(:true_expression, [Sonx.ChordSheet.evaluatable()], default: [])
    field(:false_expression, [Sonx.ChordSheet.evaluatable()], default: [])
    field(:line, non_neg_integer() | nil, default: nil)
    field(:column, non_neg_integer() | nil, default: nil)
    field(:offset, non_neg_integer() | nil, default: nil)
  end

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      variable: Keyword.get(opts, :variable),
      value_test: Keyword.get(opts, :value_test),
      true_expression: Keyword.get(opts, :true_expression, []),
      false_expression: Keyword.get(opts, :false_expression, []),
      line: Keyword.get(opts, :line),
      column: Keyword.get(opts, :column),
      offset: Keyword.get(opts, :offset)
    }
  end

  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = ternary) do
    %__MODULE__{
      variable: ternary.variable,
      value_test: ternary.value_test,
      true_expression: Enum.map(ternary.true_expression, &clone_evaluatable/1),
      false_expression: Enum.map(ternary.false_expression, &clone_evaluatable/1),
      line: ternary.line,
      column: ternary.column,
      offset: ternary.offset
    }
  end

  defp clone_evaluatable(%__MODULE__{} = t), do: clone(t)

  defp clone_evaluatable(%Literal{} = l), do: Literal.clone(l)
end

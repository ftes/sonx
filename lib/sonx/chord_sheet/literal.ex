defmodule Sonx.ChordSheet.Literal do
  @moduledoc """
  Represents a literal string value, used in grid/tab sections and ternary expressions.
  """

  use TypedStruct

  typedstruct do
    field(:string, String.t(), enforce: true)
  end

  @spec new(String.t()) :: t()
  def new(string), do: %__MODULE__{string: string}

  @spec clone(t()) :: t()
  def clone(%__MODULE__{string: string}), do: %__MODULE__{string: string}
end

defmodule Sonx.ChordSheet.SoftLineBreak do
  @moduledoc """
  Represents a soft line break in lyrics, typically rendered as a space or optional break point.
  """

  use TypedStruct

  typedstruct do
    field(:content, String.t(), default: " ")
  end

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec clone(t()) :: t()
  def clone(_), do: %__MODULE__{}
end

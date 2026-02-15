defmodule Sonx.ChordSheet.Comment do
  @moduledoc """
  Represents a comment in a chord sheet (e.g. `# this is a comment` in ChordPro).
  Comments are not rendered in formatted output.
  """

  use TypedStruct

  typedstruct do
    field(:content, String.t(), enforce: true)
  end

  @spec new(String.t()) :: t()
  def new(content), do: %__MODULE__{content: content}

  @spec clone(t()) :: t()
  def clone(%__MODULE__{content: content}), do: %__MODULE__{content: content}
end

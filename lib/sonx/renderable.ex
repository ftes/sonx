defprotocol Sonx.Renderable do
  @moduledoc """
  Protocol for items that can be rendered in formatted chord sheet output.
  """

  @doc "Returns true if the item should be visible in formatted output."
  @spec renderable?(t()) :: boolean()
  def renderable?(item)
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.ChordLyricsPair do
  def renderable?(_pair), do: true
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.Tag do
  def renderable?(tag), do: Sonx.ChordSheet.Tag.renderable?(tag)
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.Comment do
  def renderable?(_comment), do: false
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.Ternary do
  def renderable?(_ternary), do: true
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.Literal do
  def renderable?(_literal), do: true
end

defimpl Sonx.Renderable, for: Sonx.ChordSheet.SoftLineBreak do
  def renderable?(_soft_line_break), do: false
end

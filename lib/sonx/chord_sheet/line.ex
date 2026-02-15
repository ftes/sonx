defmodule Sonx.ChordSheet.Line do
  @moduledoc """
  Represents a line in a chord sheet, consisting of items (ChordLyricsPair, Tag, Comment, etc.).
  """

  use TypedStruct

  alias Sonx.ChordSheet.{ChordLyricsPair, Comment, Tag}
  alias Sonx.ChordSheet.Literal
  alias Sonx.ChordSheet.SoftLineBreak
  alias Sonx.ChordSheet.Ternary

  @type section_type() ::
          :verse | :chorus | :bridge | :tab | :grid | :none | :part | :abc | :ly | :indeterminate

  typedstruct do
    field(:items, [Sonx.ChordSheet.item()], default: [])
    field(:type, section_type(), default: :none)
  end

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      items: Keyword.get(opts, :items, []),
      type: Keyword.get(opts, :type, :none)
    }
  end

  @doc "Returns true if the line has no items."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{items: []}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc "Returns true if the line contains renderable items."
  @spec has_renderable_items?(t()) :: boolean()
  def has_renderable_items?(%__MODULE__{items: items}) do
    Enum.any?(items, &Sonx.Renderable.renderable?/1)
  end

  @doc "Adds an item to the line."
  @spec add_item(t(), Sonx.ChordSheet.item()) :: t()
  def add_item(%__MODULE__{items: items} = line, item) do
    %{line | items: items ++ [item]}
  end

  @doc "Returns a deep copy of the line."
  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = line) do
    %__MODULE__{
      items: Enum.map(line.items, &clone_item/1),
      type: line.type
    }
  end

  @doc "Maps over items, returning a new line."
  @spec map_items(t(), (Sonx.ChordSheet.item() -> Sonx.ChordSheet.item() | nil)) ::
          t()
  def map_items(%__MODULE__{} = line, func) do
    new_items =
      line.items
      |> Enum.map(fn item -> func.(clone_item(item)) end)
      |> Enum.reject(&is_nil/1)
      |> List.flatten()

    %{line | items: new_items}
  end

  @doc "Returns a new line with the given fields updated."
  @spec set(t(), keyword()) :: t()
  def set(%__MODULE__{} = line, attrs) do
    %__MODULE__{
      items: Keyword.get(attrs, :items, line.items),
      type: Keyword.get(attrs, :type, line.type)
    }
  end

  @doc "Returns true if the line's single tag is a section start."
  @spec section_start?(t()) :: boolean()
  def section_start?(%__MODULE__{items: [%Tag{} = tag]}), do: Tag.section_start?(tag)
  def section_start?(_), do: false

  @doc "Returns true if the line's single tag is a section end."
  @spec section_end?(t()) :: boolean()
  def section_end?(%__MODULE__{items: [%Tag{} = tag]}), do: Tag.section_end?(tag)
  def section_end?(_), do: false

  # Clone dispatcher for item types
  defp clone_item(%ChordLyricsPair{} = item), do: ChordLyricsPair.clone(item)
  defp clone_item(%Tag{} = item), do: Tag.clone(item)
  defp clone_item(%Comment{} = item), do: Comment.clone(item)

  defp clone_item(%Ternary{} = item), do: Ternary.clone(item)

  defp clone_item(%Literal{} = item), do: Literal.clone(item)

  defp clone_item(%SoftLineBreak{} = item), do: SoftLineBreak.clone(item)
end

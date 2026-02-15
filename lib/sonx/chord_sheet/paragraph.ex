defmodule Sonx.ChordSheet.Paragraph do
  @moduledoc """
  Represents a paragraph — a group of consecutive lines separated by empty lines.
  """

  use TypedStruct

  alias Sonx.ChordSheet.Line
  alias Sonx.ChordSheet.Tag

  typedstruct do
    field(:lines, [Line.t()], default: [])
  end

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Adds a line to the paragraph."
  @spec add_line(t(), Line.t()) :: t()
  def add_line(%__MODULE__{lines: lines} = paragraph, line) do
    %{paragraph | lines: lines ++ [line]}
  end

  @doc "Derives the paragraph type from its lines."
  @spec type(t()) :: Line.section_type()
  def type(%__MODULE__{lines: []}) do
    :none
  end

  def type(%__MODULE__{lines: lines}) do
    types =
      lines
      |> Enum.map(& &1.type)
      |> Enum.reject(&(&1 == :none))
      |> Enum.uniq()

    case types do
      [] -> :none
      [single] -> single
      _multiple -> :indeterminate
    end
  end

  @doc "Returns the label from the first line's section start tag, if any."
  @spec label(t()) :: String.t() | nil
  def label(%__MODULE__{lines: []}), do: nil

  def label(%__MODULE__{lines: [first | _]}) do
    case first.items do
      [%Tag{} = tag] ->
        if Tag.has_renderable_label?(tag) do
          Tag.label(tag)
        end

      _ ->
        nil
    end
  end

  @doc "Returns true if the paragraph contains renderable items."
  @spec has_renderable_items?(t()) :: boolean()
  def has_renderable_items?(%__MODULE__{lines: lines}) do
    Enum.any?(lines, &Line.has_renderable_items?/1)
  end

  @doc "Returns true if the paragraph is a literal section (tab/grid)."
  @spec literal?(t()) :: boolean()
  def literal?(paragraph) do
    type(paragraph) in [:tab, :grid]
  end
end

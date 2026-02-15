defmodule Sonx.SongBuilder do
  @moduledoc """
  Builder for constructing Song structs during parsing.

  Tracks current line, section type, and builds up the Song incrementally.
  """

  alias Sonx.ChordSheet.{
    Line,
    Song,
    Tag
  }

  @type t() :: %__MODULE__{
          song: Song.t(),
          current_line: Line.t() | nil,
          section_type: Line.section_type(),
          warnings: [String.t()]
        }

  defstruct song: %Song{},
            current_line: nil,
            section_type: :none,
            warnings: []

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Starts a new line in the builder."
  @spec add_line(t(), keyword()) :: t()
  def add_line(%__MODULE__{} = builder, opts \\ []) do
    builder = flush_line(builder)
    type = Keyword.get(opts, :type, builder.section_type)
    %{builder | current_line: Line.new(type: type)}
  end

  @doc "Adds an item to the current line."
  @spec add_item(t(), Sonx.ChordSheet.item()) :: t()
  def add_item(%__MODULE__{current_line: nil} = builder, item) do
    builder
    |> add_line()
    |> add_item(item)
  end

  def add_item(%__MODULE__{current_line: line} = builder, %Tag{} = tag) do
    builder = handle_tag(builder, tag)
    %{builder | current_line: Line.add_item(line, tag)}
  end

  def add_item(%__MODULE__{current_line: line} = builder, item) do
    %{builder | current_line: Line.add_item(line, item)}
  end

  @doc "Adds a warning message."
  @spec add_warning(t(), String.t()) :: t()
  def add_warning(%__MODULE__{warnings: warnings} = builder, warning) do
    %{builder | warnings: warnings ++ [warning]}
  end

  @doc "Finalizes and returns the built Song."
  @spec build(t()) :: Song.t()
  def build(%__MODULE__{} = builder) do
    builder = flush_line(builder)
    %{builder.song | warnings: builder.warnings}
  end

  # --- Private ---

  defp flush_line(%__MODULE__{current_line: nil} = builder), do: builder

  defp flush_line(%__MODULE__{current_line: line, song: song} = builder) do
    %{builder | song: Song.add_line(song, line), current_line: nil}
  end

  defp handle_tag(%__MODULE__{} = builder, %Tag{} = tag) do
    cond do
      Tag.section_start?(tag) ->
        %{builder | section_type: Tag.section_type(tag) || :none}

      Tag.section_end?(tag) ->
        %{builder | section_type: :none}

      true ->
        builder
    end
  end
end

defmodule Sonx.ChordSheet.Song do
  @moduledoc """
  Represents a song in a chord sheet. The central data structure (IR).

  Every parser produces a Song, and every formatter consumes one.
  """

  use TypedStruct

  alias Sonx.{Chord, Key}

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Line,
    Metadata,
    Paragraph,
    Tag
  }

  typedstruct do
    field(:lines, [Line.t()], default: [])
    field(:warnings, [String.t()], default: [])
  end

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      lines: Keyword.get(opts, :lines, []),
      warnings: Keyword.get(opts, :warnings, [])
    }
  end

  # --- Metadata ---

  @doc "Extracts metadata from the song's tag items."
  @spec metadata(t()) :: Metadata.t()
  def metadata(%__MODULE__{lines: lines}) do
    Enum.reduce(lines, Metadata.new(), &collect_line_metadata/2)
  end

  defp collect_line_metadata(line, meta) do
    Enum.reduce(line.items, meta, fn
      %Tag{} = tag, acc ->
        if Tag.meta_tag?(tag), do: Metadata.add(acc, tag.name, tag.value), else: acc

      _, acc ->
        acc
    end)
  end

  @doc "Returns the song title, or nil."
  @spec title(t()) :: String.t() | nil
  def title(song), do: Metadata.get_single(metadata(song), "title")

  @doc "Returns the song subtitle, or nil."
  @spec subtitle(t()) :: String.t() | nil
  def subtitle(song), do: Metadata.get_single(metadata(song), "subtitle")

  @doc "Returns the song key, or nil."
  @spec key(t()) :: String.t() | nil
  def key(song), do: Metadata.get_single(metadata(song), "key")

  @doc "Returns the current Key object, or nil."
  @spec current_key(t()) :: Key.t() | nil
  def current_key(song), do: Key.wrap(key(song))

  # --- Paragraphs ---

  @doc "Groups lines into paragraphs (separated by empty lines)."
  @spec paragraphs(t()) :: [Paragraph.t()]
  def paragraphs(%__MODULE__{lines: lines}) do
    lines_to_paragraphs(lines)
  end

  @doc "Returns body paragraphs (skipping leading non-renderable paragraphs)."
  @spec body_paragraphs(t()) :: [Paragraph.t()]
  def body_paragraphs(song) do
    song
    |> paragraphs()
    |> Enum.drop_while(fn p -> not Paragraph.has_renderable_items?(p) end)
  end

  @doc "Returns body lines (skipping leading non-renderable lines)."
  @spec body_lines(t()) :: [Line.t()]
  def body_lines(%__MODULE__{lines: lines}) do
    Enum.drop_while(lines, fn line -> not Line.has_renderable_items?(line) end)
  end

  # --- Transformation ---

  @doc "Maps over all items in the song, returning a new song."
  @spec map_items(t(), (Sonx.ChordSheet.item() ->
                          Sonx.ChordSheet.item() | [Sonx.ChordSheet.item()] | nil)) ::
          t()
  def map_items(%__MODULE__{} = song, func) do
    new_lines = Enum.map(song.lines, &map_line_items(&1, func))
    %{song | lines: new_lines}
  end

  defp map_line_items(line, func) do
    new_items =
      Enum.flat_map(line.items, fn item ->
        case func.(item) do
          nil -> []
          items when is_list(items) -> items
          item -> [item]
        end
      end)

    %{line | items: new_items}
  end

  @doc "Iterates over all items in the song."
  @spec foreach_item(t(), (Sonx.ChordSheet.item() -> any())) :: :ok
  def foreach_item(%__MODULE__{lines: lines}, func) do
    Enum.each(lines, fn line ->
      Enum.each(line.items, func)
    end)

    :ok
  end

  @doc "Maps over lines, returning a new song. Return nil to remove a line."
  @spec map_lines(t(), (Line.t() -> Line.t() | nil)) :: t()
  def map_lines(%__MODULE__{} = song, func) do
    new_lines =
      song.lines
      |> Enum.map(func)
      |> Enum.reject(&is_nil/1)

    %{song | lines: new_lines}
  end

  @doc "Returns a deep clone of the song."
  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = song) do
    %__MODULE__{
      lines: Enum.map(song.lines, &Line.clone/1),
      warnings: song.warnings
    }
  end

  @doc "Returns all unique chord strings used in the song."
  @spec get_chords(t()) :: [String.t()]
  def get_chords(%__MODULE__{} = song) do
    song.lines
    |> Enum.flat_map(& &1.items)
    |> Enum.filter(&match?(%ChordLyricsPair{}, &1))
    |> Enum.map(& &1.chords)
    |> Enum.filter(&(&1 != "" and &1 != nil))
    |> Enum.map(fn chords ->
      case Chord.parse(chords) do
        nil -> nil
        chord -> Chord.to_string(chord)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc "Transposes the song by delta semitones."
  @spec transpose(t(), integer(), keyword()) :: t()
  def transpose(%__MODULE__{} = song, delta, opts \\ []) do
    accidental = Keyword.get(opts, :accidental)
    _normalize_suffix = Keyword.get(opts, :normalize_chord_suffix, false)
    transposed_key = nil

    map_items(song, fn
      %Tag{name: "key", value: value} = tag ->
        key = Key.parse!(value) |> Key.transpose(delta) |> Key.normalize()
        key = if accidental, do: Key.use_accidental(key, accidental), else: key
        Tag.set(tag, value: Key.to_string(key))

      %ChordLyricsPair{} = pair ->
        ChordLyricsPair.transpose(pair, delta, transposed_key)

      item ->
        item
    end)
  end

  @doc "Changes the song key to the specified new key."
  @spec change_key(t(), String.t() | Key.t()) :: t()
  def change_key(%__MODULE__{} = song, new_key) do
    current = current_key(song)

    if current == nil do
      raise "Cannot change song key: the original key is unknown. Set a key directive first."
    end

    target = Key.wrap!(new_key)
    delta = Key.distance(current, target)
    transpose(song, delta, accidental: target.accidental)
  end

  @doc "Sets the key metadata on the song."
  @spec set_key(t(), String.t() | nil) :: t()
  def set_key(song, key) do
    change_metadata(song, "key", key)
  end

  @doc "Sets the capo metadata on the song."
  @spec set_capo(t(), integer() | nil) :: t()
  def set_capo(song, nil), do: change_metadata(song, "capo", nil)
  def set_capo(song, capo), do: change_metadata(song, "capo", Integer.to_string(capo))

  @doc "Changes a metadata directive value."
  @spec change_metadata(t(), String.t(), String.t() | nil) :: t()
  def change_metadata(%__MODULE__{} = song, name, value) do
    found = Ref.new(false)

    updated =
      map_items(song, fn
        %Tag{} = tag when tag.name == name ->
          if value == nil do
            Ref.put(found, true)
            nil
          else
            Ref.put(found, true)
            Tag.set(tag, value: value)
          end

        item ->
          item
      end)

    if not Ref.get(found) and value != nil do
      # Insert new directive
      line = Line.new(items: [Tag.new(name, value)])
      %{updated | lines: [line | updated.lines]}
    else
      updated
    end
  end

  @doc "Switches all chords to the specified accidental."
  @spec use_accidental(t(), Key.accidental()) :: t()
  def use_accidental(%__MODULE__{} = song, accidental) do
    map_items(song, fn
      %ChordLyricsPair{} = pair ->
        ChordLyricsPair.use_accidental(pair, accidental)

      item ->
        item
    end)
  end

  @doc "Adds a line to the song."
  @spec add_line(t(), Line.t()) :: t()
  def add_line(%__MODULE__{lines: lines} = song, line) do
    %{song | lines: lines ++ [line]}
  end

  # --- Private ---

  defp lines_to_paragraphs(lines) do
    {paragraphs, current} =
      lines
      |> Enum.with_index()
      |> Enum.reduce({[], Paragraph.new()}, fn {line, idx}, {paragraphs, current} ->
        next_line = Enum.at(lines, idx + 1)

        cond do
          Line.empty?(line) ->
            {paragraphs ++ [current], Paragraph.new()}

          Line.section_end?(line) and next_line != nil and not Line.empty?(next_line) ->
            {paragraphs ++ [current], Paragraph.new()}

          Line.has_renderable_items?(line) ->
            {paragraphs, Paragraph.add_line(current, line)}

          true ->
            {paragraphs, current}
        end
      end)

    paragraphs ++ [current]
  end
end

# Simple mutable reference for use in change_metadata
defmodule Ref do
  @moduledoc false
  def new(value) do
    {:ok, pid} = Agent.start_link(fn -> value end)
    pid
  end

  def get(pid), do: Agent.get(pid, & &1)
  def put(pid, value), do: Agent.update(pid, fn _ -> value end)
end

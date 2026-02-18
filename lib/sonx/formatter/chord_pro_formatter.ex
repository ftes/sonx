defmodule Sonx.Formatter.ChordProFormatter do
  @moduledoc """
  Formats a Song back to ChordPro format.

  Example output:
      {title: My Song}
      {artist: John Doe}

      {start_of_verse}
      [Am]Hello [C]world
      {end_of_verse}
  """

  @behaviour Sonx.Formatter

  alias Sonx.{Chord, Evaluatable}

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  @impl true
  @spec format(Song.t(), keyword()) :: String.t()
  def format(%Song{} = song, opts \\ []) do
    if Keyword.get(opts, :chord_diagrams, false) do
      raise ArgumentError, ":chord_diagrams is not supported by ChordProFormatter"
    end

    metadata = Song.metadata(song)
    {meta_lines, content_lines} = separate_metadata(song.lines)

    meta_section = format_lines(meta_lines, metadata, opts)
    content_section = format_lines(content_lines, metadata, opts)

    combine_sections(meta_section, content_section)
  end

  # --- Metadata separation ---

  defp separate_metadata(lines) do
    # Metadata lines are leading lines with a single meta tag
    {meta, content, _found_content} =
      Enum.reduce(lines, {[], [], false}, fn line, {meta, content, found_content} ->
        if not found_content and single_meta_tag_line?(line) do
          {meta ++ [line], content, false}
        else
          {meta, content ++ [line], true}
        end
      end)

    # Drop leading empty lines from content — combine_sections adds the separator
    content = Enum.drop_while(content, &(&1.items == []))

    {meta, content}
  end

  defp single_meta_tag_line?(%Line{items: [%Tag{} = tag]}) do
    Tag.meta_tag?(tag) and not Tag.section_start?(tag) and not Tag.section_end?(tag)
  end

  defp single_meta_tag_line?(_), do: false

  # --- Line formatting ---

  defp format_lines(lines, metadata, opts) do
    lines
    |> Enum.map_join("\n", &format_line(&1, metadata, opts))
  end

  defp format_line(%Line{items: items}, metadata, opts) do
    items
    |> Enum.map(&format_item(&1, metadata, opts))
    |> IO.iodata_to_binary()
  end

  # --- Item formatting ---

  defp format_item(%ChordLyricsPair{} = pair, _metadata, opts) do
    chord_part = format_chord(pair, opts)
    lyrics = pair.lyrics || ""
    chord_part <> lyrics
  end

  defp format_item(%Tag{} = tag, _metadata, _opts) do
    format_tag(tag)
  end

  defp format_item(%Comment{content: content}, _metadata, _opts) do
    "##{content}"
  end

  defp format_item(%SoftLineBreak{}, _metadata, _opts) do
    "\\ "
  end

  defp format_item(%Ternary{} = ternary, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      Evaluatable.evaluate(ternary, metadata)
    else
      format_ternary(ternary)
    end
  end

  defp format_item(%Literal{string: string}, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      Evaluatable.evaluate(%Literal{string: string}, metadata)
    else
      string
    end
  end

  # --- Chord formatting ---

  defp format_chord(%ChordLyricsPair{annotation: ann}, _opts) when is_binary(ann) and ann != "" do
    "[*#{ann}]"
  end

  defp format_chord(%ChordLyricsPair{chords: ""}, _opts), do: ""
  defp format_chord(%ChordLyricsPair{chords: nil}, _opts), do: ""

  defp format_chord(%ChordLyricsPair{chords: chords}, opts) do
    unicode_accidentals? = Keyword.get(opts, :unicode_accidentals, false)
    normalize? = Keyword.get(opts, :normalize_chords, false)

    chord_str =
      if normalize? do
        case Chord.parse(chords) do
          nil -> chords
          chord -> Chord.to_string(chord, unicode_accidentals: unicode_accidentals?)
        end
      else
        chords
      end

    "[#{chord_str}]"
  end

  # --- Tag formatting ---

  defp format_tag(%Tag{} = tag) do
    name = tag.original_name

    cond do
      Tag.has_attributes?(tag) ->
        attrs_str =
          tag.attributes
          |> Enum.map_join(" ", fn {k, v} -> "#{k}=\"#{v}\"" end)

        "{#{name}: #{attrs_str}}"

      Tag.has_value?(tag) ->
        "{#{name}: #{tag.value}}"

      true ->
        "{#{name}}"
    end
  end

  # --- Ternary formatting ---

  defp format_ternary(%Ternary{} = t) do
    var = t.variable || ""
    value_test = if t.value_test, do: "=#{t.value_test}", else: ""

    true_part = format_expression_range(t.true_expression)
    false_part = format_expression_range(t.false_expression)

    if true_part != "" or false_part != "" do
      "%{#{var}#{value_test}|#{true_part}|#{false_part}}"
    else
      "%{#{var}#{value_test}}"
    end
  end

  defp format_expression_range([]), do: ""

  defp format_expression_range(expressions) do
    Enum.map_join(expressions, "", fn
      %Ternary{} = t -> format_ternary(t)
      %Literal{string: s} -> s
    end)
  end

  # --- Section combination ---

  defp combine_sections("", content), do: content
  defp combine_sections(meta, ""), do: meta

  defp combine_sections(meta, content) do
    meta <> "\n\n" <> content
  end
end

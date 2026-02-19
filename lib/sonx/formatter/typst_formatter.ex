defmodule Sonx.Formatter.TypstFormatter do
  @moduledoc """
  Formats a Song as a Typst file for the conchord package.

  Uses the `chordify` show rule with `[Chord]` inline syntax.

  See https://typst.app/universe/package/conchord/

  Example output:
      #import "@preview/conchord:0.4.0": chordify
      #show: chordify

      = Let It Be
      == The Beatles

      === Verse 1

      [C] When I find myself in [G] times of trouble \\
      [Am] Mother Mary [F] comes to me
  """

  @behaviour Sonx.Formatter

  alias Sonx.{Chord, Evaluatable}

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    Metadata,
    SoftLineBreak,
    Song,
    Tag,
    Tags,
    Ternary
  }

  @conchord_version "0.4.0"

  @diagram_schema NimbleOptions.new!(
                    n: [type: :pos_integer, default: 4, doc: "Number of chords per row (Typst `N`)"],
                    width: [type: :string, doc: "Width of the chord library (e.g., \"400pt\")"]
                  )

  @header_tags [Tags.title(), Tags.subtitle(), Tags.artist()]

  @meta_comment_tags ~w(key capo tempo time composer lyricist album year duration)

  @section_labels %{
    "start_of_verse" => "Verse",
    "start_of_chorus" => "Chorus",
    "start_of_bridge" => "Bridge",
    "start_of_part" => nil,
    "start_of_tab" => "Tab",
    "start_of_grid" => "Grid"
  }

  @impl true
  @spec format(Song.t(), keyword()) :: String.t()
  def format(%Song{} = song, opts \\ []) do
    metadata = Song.metadata(song)

    preamble = format_preamble(opts)
    header = format_header(song)
    meta_comments = format_meta_comments(metadata)
    body = format_body(song, metadata, opts)

    [preamble, header, meta_comments, body]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  # --- Preamble ---

  @doc "Generates Typst conchord sized-chordlib preamble."
  @spec chord_diagrams(keyword()) :: String.t()
  def chord_diagrams(opts \\ []) do
    params = sized_chordlib_params(opts)

    "#import \"@preview/conchord:#{@conchord_version}\": sized-chordlib\n" <>
      "#context sized-chordlib(#{params})"
  end

  defp format_preamble(opts) do
    case Keyword.get(opts, :chord_diagrams, false) do
      false ->
        "#import \"@preview/conchord:#{@conchord_version}\": chordify\n#show: chordify"

      diagram_opts ->
        params = sized_chordlib_params(diagram_opts)

        "#import \"@preview/conchord:#{@conchord_version}\": chordify, sized-chordlib\n" <>
          "#show: chordify\n" <>
          "#context sized-chordlib(#{params})"
    end
  end

  defp sized_chordlib_params(diagram_opts) do
    diagram_opts = if is_list(diagram_opts), do: diagram_opts, else: []
    diagram_opts = NimbleOptions.validate!(diagram_opts, @diagram_schema)

    [{"N", diagram_opts[:n]}]
    |> then(fn params ->
      if width = diagram_opts[:width], do: params ++ [{"width", width}], else: params
    end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  # --- Header ---

  defp format_header(song) do
    title = Song.title(song)
    subtitle = Song.subtitle(song)
    artist = format_artist(song)

    [
      heading("=", title),
      heading("==", subtitle),
      heading("==", artist)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp heading(_prefix, nil), do: nil
  defp heading(_prefix, ""), do: nil
  defp heading(prefix, text), do: "#{prefix} #{text}"

  defp format_artist(song) do
    song
    |> Song.metadata()
    |> Metadata.get("artist")
    |> case do
      nil -> nil
      values when is_list(values) -> Enum.join(values, ", ")
      value -> value
    end
  end

  # --- Meta comments ---

  defp format_meta_comments(%Metadata{} = metadata) do
    @meta_comment_tags
    |> Enum.flat_map(fn key ->
      case Metadata.get(metadata, key) do
        nil -> []
        values when is_list(values) -> [{"#{key}", Enum.join(values, ", ")}]
        value -> [{key, value}]
      end
    end)
    |> Enum.map_join("\n", fn {key, value} -> "// #{key}: #{value}" end)
  end

  # --- Body ---

  defp format_body(%Song{lines: lines}, metadata, opts) do
    # Skip leading metadata-only lines (handled by header/meta_comments)
    lines
    |> Enum.drop_while(&meta_only_line?/1)
    |> group_lines(metadata, opts)
  end

  defp meta_only_line?(%Line{items: [%Tag{} = tag]}) do
    tag.name in @header_tags or tag.name in @meta_comment_tags or Tags.meta_tag?(tag.name)
  end

  defp meta_only_line?(%Line{items: []}), do: true
  defp meta_only_line?(_), do: false

  # Group lines into paragraphs (separated by empty lines) and join content
  # lines within a paragraph with ` \` continuation
  defp group_lines(lines, metadata, opts) do
    lines
    |> Enum.chunk_by(&(&1.items == []))
    |> Enum.map(fn chunk ->
      if Enum.all?(chunk, &(&1.items == [])) do
        # Empty line group → paragraph break
        :break
      else
        format_chunk(chunk, metadata, opts)
      end
    end)
    |> Enum.reject(&(&1 == "" or &1 == :break))
    |> Enum.join("\n\n")
  end

  defp format_chunk(lines, metadata, opts) do
    {section_lines, content_lines} =
      Enum.split_with(lines, fn line ->
        match?([%Tag{}], line.items) and
          (Tags.section_start?(hd(line.items).name) or Tags.section_end?(hd(line.items).name))
      end)

    section_part =
      section_lines
      |> Enum.map(&format_line(&1, metadata, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    content_part =
      content_lines
      |> Enum.filter(&Line.has_renderable_items?/1)
      |> Enum.map(&format_line(&1, metadata, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" \\\n")

    [section_part, content_part]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  # --- Lines ---

  defp format_line(%Line{} = line, metadata, opts) do
    chord_diagrams? = Keyword.get(opts, :chord_diagrams, false) != false

    line.items
    |> Enum.map(&prepare_item(&1, metadata, opts))
    |> merge_chord_only_pairs(chord_diagrams?)
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  # Returns {:chord_only, chord_str} | string for merging
  defp prepare_item(%ChordLyricsPair{} = pair, _metadata, opts) do
    chord_part = format_chord(pair, opts)
    lyrics = escape(pair.lyrics || "")

    case {chord_part, lyrics} do
      {"", ""} -> ""
      {"", lyrics} -> lyrics
      {_chord, ""} -> {:chord_only, chord_content(pair, opts)}
      {chord, lyrics} -> chord <> " " <> lyrics
    end
  end

  defp prepare_item(%Tag{} = tag, _metadata, _opts) do
    format_tag(tag)
  end

  defp prepare_item(%Comment{content: content}, _metadata, _opts) do
    "// #{content}"
  end

  defp prepare_item(%SoftLineBreak{}, _metadata, _opts) do
    " "
  end

  defp prepare_item(%Ternary{} = ternary, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      escape(Evaluatable.evaluate(ternary, metadata))
    else
      ""
    end
  end

  defp prepare_item(%Literal{} = literal, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      escape(Evaluatable.evaluate(literal, metadata))
    else
      escape(literal.string)
    end
  end

  # Workaround: merge consecutive chord-only pairs into a single [A B C] bracket
  # to avoid overlapping chord labels. See https://github.com/sitandr/conchord/issues/18
  # When chord_diagrams is enabled, sized-chordlib can't parse concatenated names,
  # so fall back to separate [A]#h(2em) [B]#h(2em) spacing instead.
  defp merge_chord_only_pairs(items, chord_diagrams?) do
    items
    |> Enum.chunk_by(fn
      {:chord_only, _} -> :chord
      _ -> :other
    end)
    |> Enum.flat_map(fn
      [{:chord_only, _} | _] = group when not chord_diagrams? ->
        chords = Enum.map_join(group, " ", fn {:chord_only, c} -> c end)
        ["[#{chords}]"]

      [{:chord_only, _} | _] = group ->
        Enum.map(group, fn {:chord_only, c} -> "[#{c}]#h(2em) " end)

      other ->
        other
    end)
  end

  # --- Chord formatting ---

  # Returns the chord string without brackets (for concatenation into [A B C])
  defp chord_content(%ChordLyricsPair{annotation: ann}, _opts) when is_binary(ann) and ann != "" do
    escape_chord(ann)
  end

  defp chord_content(%ChordLyricsPair{chords: chords}, opts) do
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

    escape_chord(chord_str)
  end

  defp format_chord(%ChordLyricsPair{chords: ""}, _opts), do: ""
  defp format_chord(%ChordLyricsPair{chords: nil}, _opts), do: ""

  defp format_chord(%ChordLyricsPair{} = pair, opts) do
    "[#{chord_content(pair, opts)}]"
  end

  # --- Tag formatting ---

  defp format_tag(%Tag{name: name}) when name in @header_tags, do: ""

  defp format_tag(%Tag{name: name} = tag) when is_map_key(@section_labels, name) do
    base_label = @section_labels[name]

    label =
      case Tag.label(tag) do
        "" -> base_label
        l -> l
      end

    if label, do: "=== #{label}", else: ""
  end

  defp format_tag(%Tag{name: "comment", value: value}), do: "// #{value}"

  defp format_tag(%Tag{name: name}) when name in @meta_comment_tags, do: ""

  defp format_tag(%Tag{name: name} = tag) do
    cond do
      Tags.section_end?(name) -> ""
      Tags.meta_tag?(name) -> ""
      Tag.has_value?(tag) -> "// #{name}: #{tag.value}"
      true -> "// #{name}"
    end
  end

  # --- Escaping ---

  # Escape sharp signs inside chord brackets so Typst doesn't interpret # as code.
  defp escape_chord(str) when is_binary(str) do
    String.replace(str, "#", "\\#")
  end

  defp escape(str) when is_binary(str) do
    String.replace(str, ~r/[\[\]]/, fn
      "[" -> "[["
      "]" -> "]]"
    end)
  end
end

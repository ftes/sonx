defmodule Sonx.Parser.TypstParser do
  @moduledoc """
  Parses Typst chord sheets using the conchord `chordify` square-bracket syntax.

  Supports:
  - `[Chord] lyrics` inline chord notation
  - Typst headings: `=` title, `==` subtitle/artist, `===` sections
  - `//` comments for metadata (e.g. `// key: C`)
  - `\\` line continuations
  - `[[` and `]]` literal bracket escaping
  - `#import` and `#show` preamble lines (ignored)

  Example input:
      #import "@preview/conchord:0.4.0": chordify
      #show: chordify

      = Let It Be
      == The Beatles

      === Verse 1

      [C] When I find myself in [G] times of trouble \\
      [Am] Mother Mary [F] comes to me
  """

  @behaviour Sonx.Parser

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Song,
    Tag
  }

  alias Sonx.SongBuilder

  @impl true
  @spec parse(String.t(), keyword()) :: {:ok, Song.t()} | {:error, term()}
  def parse(input, _opts \\ []) do
    song = do_parse(input)
    {:ok, song}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc "Parses or raises."
  @spec parse!(String.t(), keyword()) :: Song.t()
  def parse!(input, opts \\ []) do
    case parse(input, opts) do
      {:ok, song} -> song
      {:error, reason} -> raise "Typst parse error: #{reason}"
    end
  end

  # --- Core parsing ---

  defp do_parse(input) do
    lines =
      input
      |> String.replace("\r\n", "\n")
      |> String.replace("\r", "\n")
      |> String.split("\n")

    builder = SongBuilder.new()
    builder = process_lines(lines, builder)
    SongBuilder.build(builder)
  end

  # --- Line processing ---

  defp process_lines([], builder), do: builder

  defp process_lines([line | rest], builder) do
    trimmed = String.trim(line)

    cond do
      # Skip preamble lines
      preamble_line?(trimmed) ->
        process_lines(rest, builder)

      # Empty line
      trimmed == "" ->
        process_lines(rest, SongBuilder.add_line(builder))

      # Level 1 heading: title
      String.starts_with?(trimmed, "= ") and not String.starts_with?(trimmed, "== ") ->
        title = String.trim_leading(trimmed, "= ")

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new("title", title))

        process_lines(rest, builder)

      # Level 3 heading: section (check before level 2)
      String.starts_with?(trimmed, "=== ") ->
        label = String.trim_leading(trimmed, "=== ")
        tag_name = section_label_to_tag(label)
        tag = Tag.new(tag_name, label)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(tag)

        process_lines(rest, builder)

      # Level 2 heading: subtitle or artist
      String.starts_with?(trimmed, "== ") ->
        value = String.trim_leading(trimmed, "== ")
        # First == is subtitle, subsequent are artist
        tag_name = heading2_tag_name(builder)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new(tag_name, value))

        process_lines(rest, builder)

      # Comment line with metadata
      String.starts_with?(trimmed, "// ") ->
        comment_content = String.trim_leading(trimmed, "// ")
        builder = parse_comment(builder, comment_content)
        process_lines(rest, builder)

      # Content line (may contain chords)
      true ->
        # Strip trailing backslash (line continuation)
        content = strip_continuation(trimmed)
        pairs = parse_content_line(content)

        builder = SongBuilder.add_line(builder)

        builder =
          Enum.reduce(pairs, builder, fn pair, b ->
            SongBuilder.add_item(b, pair)
          end)

        process_lines(rest, builder)
    end
  end

  # --- Preamble detection ---

  defp preamble_line?(line) do
    String.starts_with?(line, "#import ") or
      String.starts_with?(line, "#show") or
      String.starts_with?(line, "#set ") or
      String.starts_with?(line, "#context ")
  end

  # --- Heading 2 logic ---

  defp heading2_tag_name(builder) do
    # Check if we already have a subtitle tag (in flushed lines or current line)
    all_items =
      (builder.song.lines ++ if(builder.current_line, do: [builder.current_line], else: []))
      |> Enum.flat_map(& &1.items)

    has_subtitle? = Enum.any?(all_items, &match?(%Tag{name: "subtitle"}, &1))

    if has_subtitle?, do: "artist", else: "subtitle"
  end

  # --- Comment/metadata parsing ---

  @meta_keys ~w(key capo tempo time composer lyricist album year duration)

  defp parse_comment(builder, content) do
    case String.split(content, ":", parts: 2) do
      [key, value] ->
        trimmed_key = String.trim(key)

        if trimmed_key in @meta_keys do
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new(trimmed_key, String.trim(value)))
        else
          # Plain comment — skip
          builder
        end

      _ ->
        builder
    end
  end

  # --- Line continuation ---

  defp strip_continuation(line) do
    if String.ends_with?(line, " \\") do
      String.slice(line, 0..(String.length(line) - 3)//1)
    else
      line
    end
  end

  # --- Content line parsing ---

  @chord_regex ~r/\[([^\[\]]+?)\]/
  # Placeholders for escaped brackets — use private-use Unicode chars
  @open_bracket_placeholder "\uFDD0"
  @close_bracket_placeholder "\uFDD1"

  # Matches Typst function calls like #h(2em) used as spacing artifacts
  @typst_func_regex ~r/#\w+\([^)]*\)\s*/

  defp parse_content_line(line) do
    # Replace escaped brackets with placeholders before chord detection
    line
    |> String.replace("[[", @open_bracket_placeholder)
    |> String.replace("]]", @close_bracket_placeholder)
    |> String.replace(@typst_func_regex, "")
    |> split_on_chords()
    |> build_pairs()
  end

  defp split_on_chords(line) do
    parts = Regex.split(@chord_regex, line, include_captures: true)

    Enum.flat_map(parts, fn part ->
      case Regex.run(@chord_regex, part) do
        [_, chord_name] -> expand_multi_chord(unescape_chord(chord_name))
        _ -> [{:text, restore_brackets(part)}]
      end
    end)
  end

  # Splits "[A B C]" style concatenated chords into separate chord segments
  defp expand_multi_chord(chord_name) do
    case String.split(chord_name) do
      [_single] -> [{:chord, chord_name}]
      multiple -> Enum.map(multiple, &{:chord, &1})
    end
  end

  defp restore_brackets(str) do
    str
    |> String.replace(@open_bracket_placeholder, "[")
    |> String.replace(@close_bracket_placeholder, "]")
  end

  # Unescape \# back to # inside chord names (formatter escapes # for Typst)
  defp unescape_chord(str) do
    String.replace(str, "\\#", "#")
  end

  defp build_pairs(segments) do
    # Walk through segments building ChordLyricsPairs
    # A chord followed by text = one pair
    # Text at the start without a chord = lyrics-only pair
    do_build_pairs(segments, nil, [])
  end

  defp do_build_pairs([], nil, acc), do: Enum.reverse(acc)

  defp do_build_pairs([], current_chord, acc) do
    Enum.reverse([ChordLyricsPair.new(current_chord, "") | acc])
  end

  defp do_build_pairs([{:text, text} | rest], nil, acc) do
    if text == "" do
      do_build_pairs(rest, nil, acc)
    else
      do_build_pairs(rest, nil, [ChordLyricsPair.new("", text) | acc])
    end
  end

  defp do_build_pairs([{:text, text} | rest], current_chord, acc) do
    # Strip the single leading space that conchord puts between ] and the word
    lyrics = strip_leading_space(text)
    do_build_pairs(rest, nil, [ChordLyricsPair.new(current_chord, lyrics) | acc])
  end

  defp do_build_pairs([{:chord, chord} | rest], nil, acc) do
    do_build_pairs(rest, chord, acc)
  end

  defp do_build_pairs([{:chord, chord} | rest], current_chord, acc) do
    # Previous chord had no lyrics
    do_build_pairs(rest, chord, [ChordLyricsPair.new(current_chord, "") | acc])
  end

  # --- Section label mapping ---

  @section_map %{
    "verse" => "start_of_verse",
    "chorus" => "start_of_chorus",
    "bridge" => "start_of_bridge",
    "tab" => "start_of_tab",
    "grid" => "start_of_grid",
    "intro" => "start_of_part",
    "outro" => "start_of_part",
    "pre-chorus" => "start_of_part",
    "interlude" => "start_of_part",
    "instrumental" => "start_of_part"
  }

  defp strip_leading_space(" " <> rest), do: rest
  defp strip_leading_space(str), do: str

  defp section_label_to_tag(label) do
    lower = String.downcase(String.trim(label))
    # Strip trailing numbers/spaces: "Verse 1" -> "verse"
    base = Regex.replace(~r/\s*\d+$/, lower, "")
    Map.get(@section_map, base, "start_of_part")
  end
end

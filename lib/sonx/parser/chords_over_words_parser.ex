defmodule Sonx.Parser.ChordsOverWordsParser do
  @moduledoc """
  Parses chord sheets in "chords over words" format.

  Supports:
  - Chords on one line, lyrics on the next
  - Optional YAML-style frontmatter delimited by `---`
  - ChordPro directives embedded in the text
  - Section headers like `Verse:` or `Chorus:`

  Example input:
      ---
      title: My Song
      key: C
      ---
      Verse:
           C       G
      Hello world, it's
           Am      F
      a beautiful day
  """

  @behaviour Sonx.Parser

  alias Sonx.Chord

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
      {:error, reason} -> raise "ChordsOverWords parse error: #{reason}"
    end
  end

  # --- Core parsing ---

  defp do_parse(input) do
    lines = split_lines(input)
    {metadata, content_lines} = extract_frontmatter(lines)

    builder = SongBuilder.new()

    # Add frontmatter metadata as tag lines
    builder =
      Enum.reduce(metadata, builder, fn {key, value}, b ->
        b
        |> SongBuilder.add_line()
        |> SongBuilder.add_item(Tag.new(key, value))
      end)

    # Process content lines in pairs (chord line + lyric line)
    builder = process_content_lines(content_lines, builder)

    SongBuilder.build(builder)
  end

  defp split_lines(input) do
    input
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n")
  end

  # --- Frontmatter ---

  defp extract_frontmatter(["---" | rest]) do
    case Enum.find_index(rest, &(&1 == "---")) do
      nil ->
        {[], ["---" | rest]}

      idx ->
        frontmatter_lines = Enum.take(rest, idx)
        content_lines = Enum.drop(rest, idx + 1)
        metadata = parse_frontmatter(frontmatter_lines)
        {metadata, content_lines}
    end
  end

  defp extract_frontmatter(lines), do: {[], lines}

  defp parse_frontmatter(lines) do
    Enum.flat_map(lines, fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          [{String.trim(key), String.trim(value)}]

        _ ->
          []
      end
    end)
  end

  # --- Content processing ---

  @section_header_regex ~r/^([A-Za-z][A-Za-z0-9 ]*):$/
  @directive_regex ~r/^\{([^}]*)\}$/

  defp process_content_lines([], builder), do: builder

  defp process_content_lines([line | rest], builder) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        # Empty line
        process_content_lines(rest, SongBuilder.add_line(builder))

      Regex.match?(@directive_regex, trimmed) ->
        # ChordPro directive
        [_, inner] = Regex.run(@directive_regex, trimmed)
        tag = parse_directive(inner)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(tag)

        process_content_lines(rest, builder)

      Regex.match?(@section_header_regex, trimmed) ->
        # Section header like "Verse:" or "Chorus:"
        [_, section_name] = Regex.run(@section_header_regex, trimmed)
        tag_name = section_name_to_tag(section_name)
        tag = Tag.new(tag_name, section_name)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(tag)

        process_content_lines(rest, builder)

      chord_line?(line) ->
        # This looks like a chord line — pair with next line
        {lyric_line, remaining} = pop_lyric_line(rest)
        pairs = pair_chords_and_lyrics(line, lyric_line)

        builder = SongBuilder.add_line(builder)

        builder =
          Enum.reduce(pairs, builder, fn pair, b ->
            SongBuilder.add_item(b, pair)
          end)

        process_content_lines(remaining, builder)

      true ->
        # Plain lyrics line
        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(ChordLyricsPair.new("", line))

        process_content_lines(rest, builder)
    end
  end

  defp pop_lyric_line([]), do: {nil, []}

  defp pop_lyric_line([next | rest]) do
    trimmed = String.trim(next)

    if trimmed == "" or chord_line?(next) or Regex.match?(@section_header_regex, trimmed) do
      # Next line is not lyrics — chord line stands alone
      {nil, [next | rest]}
    else
      {next, rest}
    end
  end

  # --- Chord line detection ---

  defp chord_line?(line) do
    trimmed = String.trim(line)
    if trimmed == "", do: false, else: do_chord_line_check(trimmed)
  end

  defp do_chord_line_check(trimmed) do
    tokens = String.split(trimmed)
    chord_count = Enum.count(tokens, &chord_token?/1)
    # Consider it a chord line if more than half the tokens are chords
    # and there's at least one chord
    chord_count > 0 and chord_count / length(tokens) >= 0.5
  end

  defp chord_token?(token) do
    starts_like_chord?(token) and Chord.parse(token) != nil
  end

  defp starts_like_chord?(<<c, _rest::binary>>) when c in ?A..?Z or c == ?# or c == ?(, do: true

  defp starts_like_chord?(_), do: false

  # --- Chord/lyrics pairing ---

  defp pair_chords_and_lyrics(chord_line, nil) do
    # Chord line with no lyrics
    extract_chord_positions(chord_line)
    |> Enum.map(fn {chord, _pos} -> ChordLyricsPair.new(chord, "") end)
  end

  defp pair_chords_and_lyrics(chord_line, lyric_line) do
    chord_positions = extract_chord_positions(chord_line)

    if chord_positions == [] do
      [ChordLyricsPair.new("", lyric_line)]
    else
      build_pairs_from_positions(chord_positions, lyric_line)
    end
  end

  defp extract_chord_positions(line) do
    # Find chords and their column positions in the line
    regex = ~r/\S+/
    matches = Regex.scan(regex, line, return: :index)

    matches
    |> Enum.flat_map(fn [{pos, len}] ->
      token = String.slice(line, pos, len)

      if chord_token?(token) do
        [{token, pos}]
      else
        []
      end
    end)
  end

  defp build_pairs_from_positions(chord_positions, lyric_line) do
    lyric_len = String.length(lyric_line)

    # Add leading lyrics if first chord doesn't start at position 0
    {_first_chord, first_pos} = hd(chord_positions)

    leading =
      if first_pos > 0 do
        lyrics = safe_slice(lyric_line, 0, first_pos)
        [ChordLyricsPair.new("", lyrics)]
      else
        []
      end

    pairs =
      chord_positions
      |> Enum.with_index()
      |> Enum.map(fn {{chord, pos}, idx} ->
        next_pos =
          case Enum.at(chord_positions, idx + 1) do
            {_, np} -> np
            nil -> lyric_len
          end

        lyrics = safe_slice(lyric_line, pos, next_pos - pos)
        ChordLyricsPair.new(chord, lyrics)
      end)

    leading ++ pairs
  end

  defp safe_slice(str, start, length) do
    str_len = String.length(str)

    cond do
      start >= str_len -> ""
      start + length > str_len -> String.slice(str, start..-1//1)
      true -> String.slice(str, start, length)
    end
  end

  # --- Directive parsing ---

  @tag_with_value_regex ~r/^([a-zA-Z_][a-zA-Z0-9_]*)(?:\s*:\s*(.*))?$/

  defp parse_directive(inner) do
    trimmed = String.trim(inner)

    case Regex.run(@tag_with_value_regex, trimmed) do
      [_, name, value] -> Tag.new(name, String.trim(value))
      [_, name] -> Tag.new(name)
      _ -> Tag.new(trimmed)
    end
  end

  # --- Section name mapping ---

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

  defp section_name_to_tag(name) do
    lower = String.downcase(String.trim(name))
    # Strip trailing numbers/spaces: "Verse 1" -> "verse"
    base = Regex.replace(~r/\s*\d+$/, lower, "")
    Map.get(@section_map, base, "start_of_part")
  end
end

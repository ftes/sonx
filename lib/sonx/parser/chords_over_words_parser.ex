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
  @repeat_notation_regex ~r/^x\d+$/i
  @no_chord_tokens MapSet.new(["N.C.", "NC"])
  @strict_suffix_regex ~r/^(?:(?:m(?![a-zA-Z])|maj|min|dim|aug|sus2|sus4|sus|add|dom)?[0-9+#b()\-oΔ]*)*$/
  @symbol_root_regex ~r/^[A-G](?:#|b)?/
  @solfege_root_regex ~r/^(?:Do|Re|Mi|Fa|Sol|La|Si)(?:#|b)?/
  @numeral_root_regex ~r/^[#b]?(?:III|VII|II|IV|VI|I|V)/
  @numeric_root_regex ~r/^[#b]?[1-7]/

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
    {content, _repeat_notation} = split_repeat_notation(trimmed)
    tokens = String.split(content)

    tokens != [] and
      Enum.all?(tokens, &chord_token?/1) and
      Enum.any?(tokens, &musical_token?/1)
  end

  defp chord_token?(token) do
    no_chord_token?(token) or
      (strict_chord_token?(token) and Chord.parse(token) != nil)
  end

  defp musical_token?(token), do: chord_token?(token)

  defp no_chord_token?(token), do: MapSet.member?(@no_chord_tokens, token)

  defp strict_chord_token?(token) do
    stripped = strip_optional_parens(token)

    case String.split(stripped, "/", parts: 2) do
      [main] ->
        note_with_suffix?(main)

      [main, bass] ->
        note_with_suffix?(main) and note_root?(bass)

      _other ->
        false
    end
  end

  defp strip_optional_parens("(" <> rest) do
    if String.ends_with?(rest, ")") do
      String.slice(rest, 0, String.length(rest) - 1)
    else
      "(" <> rest
    end
  end

  defp strip_optional_parens(token), do: token

  defp note_with_suffix?(token) do
    Enum.any?(
      [@symbol_root_regex, @solfege_root_regex, @numeral_root_regex, @numeric_root_regex],
      fn root_regex ->
        case Regex.run(root_regex, token) do
          [root] ->
            suffix = String.replace_prefix(token, root, "")
            Regex.match?(@strict_suffix_regex, suffix)

          _ ->
            false
        end
      end
    )
  end

  defp note_root?(token) do
    Enum.any?(
      [@symbol_root_regex, @solfege_root_regex, @numeral_root_regex, @numeric_root_regex],
      fn root_regex ->
        Regex.match?(root_regex, token) and Regex.run(root_regex, token) == [token]
      end
    )
  end

  # --- Chord/lyrics pairing ---

  defp pair_chords_and_lyrics(chord_line, nil) do
    {content, repeat_notation} = split_repeat_notation(chord_line)

    content
    |> extract_chord_positions()
    |> Enum.map(fn {chord, _pos} -> ChordLyricsPair.new(chord, "") end)
    |> append_repeat_notation(repeat_notation)
  end

  defp pair_chords_and_lyrics(chord_line, lyric_line) do
    {content, repeat_notation} = split_repeat_notation(chord_line)
    chord_positions = extract_chord_positions(content)

    if chord_positions == [] do
      [ChordLyricsPair.new("", lyric_line)]
    else
      chord_positions
      |> build_pairs_from_positions(lyric_line)
      |> append_repeat_notation(repeat_notation)
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

  defp split_repeat_notation(trimmed) do
    tokens = String.split(trimmed)

    case Enum.split(tokens, length(tokens) - 1) do
      {[], _last} ->
        {trimmed, nil}

      {prefix, [last]} ->
        if Regex.match?(@repeat_notation_regex, last) do
          {Enum.join(prefix, " "), last}
        else
          {trimmed, nil}
        end
    end
  end

  defp append_repeat_notation([], nil), do: []
  defp append_repeat_notation([], repeat_notation), do: [ChordLyricsPair.new("", repeat_notation)]
  defp append_repeat_notation(pairs, nil), do: pairs

  defp append_repeat_notation(pairs, repeat_notation) do
    List.update_at(pairs, -1, fn pair ->
      lyrics =
        [pair.lyrics, repeat_notation]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" ")

      %{pair | lyrics: lyrics}
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

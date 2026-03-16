defmodule Sonx.Parser.UltimateGuitarParser do
  @moduledoc """
  Parses Ultimate Guitar format chord sheets.

  Ultimate Guitar uses a format similar to ChordsOverWords but with
  section markers in square brackets: `[Verse]`, `[Chorus]`, etc.

  Example:
      [Verse]
           C       G
      Hello world, it's
           Am      F
      a beautiful day

      [Chorus]
      Am    G    F    C
      Let it be, let it be
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
      {:error, reason} -> raise "UltimateGuitar parse error: #{reason}"
    end
  end

  # --- Core ---

  defp do_parse(input) do
    lines = split_lines(input)
    builder = process_lines(lines, SongBuilder.new(), nil, true)
    SongBuilder.build(builder)
  end

  defp split_lines(input) do
    input
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n")
  end

  @section_marker_regex ~r/^\[([^\]]+)\]\s*$/

  @verse_regex ~r/^\[(Verse.*)\]$/i
  @chorus_regex ~r/^\[(Chorus.*)\]$/i
  @bridge_regex ~r/^\[(Bridge.*)\]$/i
  @part_regex ~r/^\[((?:Intro|Outro|Instrumental|Interlude|Solo|Pre-Chorus)(?:\s+\d+)?)\]$/i

  @section_end_tags %{
    :verse => "end_of_verse",
    :chorus => "end_of_chorus",
    :bridge => "end_of_bridge",
    :part => "end_of_part"
  }

  @section_start_tags %{
    :verse => "start_of_verse",
    :chorus => "start_of_chorus",
    :bridge => "start_of_bridge",
    :part => "start_of_part"
  }

  @repeat_notation_regex ~r/^x\d+$/i
  @no_chord_tokens MapSet.new(["N.C.", "NC"])
  @strict_suffix_regex ~r/^(?:(?:m(?![a-zA-Z])|maj|min|dim|aug|sus2|sus4|sus|add|dom)?[0-9+#b()\-oΔ]*)*$/
  @symbol_root_regex ~r/^[A-G](?:#|b)?/
  @solfege_root_regex ~r/^(?:Do|Re|Mi|Fa|Sol|La|Si)(?:#|b)?/
  @numeral_root_regex ~r/^[#b]?(?:III|VII|II|IV|VI|I|V)/
  @numeric_root_regex ~r/^[#b]?[1-7]/

  # section_type: nil | :verse | :chorus | :bridge | :part
  # prev_empty?: whether the previous line was empty (starts true)

  defp process_lines([], builder, section_type, _prev_empty?) do
    # End of song: close any open section
    end_section(builder, section_type)
  end

  defp process_lines([line | rest], builder, section_type, prev_empty?) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        # End section on blank line if previous line was non-empty (JS isSectionEnd)
        {builder, section_type} =
          if prev_empty? do
            {builder, section_type}
          else
            {end_section(builder, section_type), nil}
          end

        builder = SongBuilder.add_line(builder)
        process_lines(rest, builder, section_type, true)

      (match = parse_section_directive(trimmed)) != nil ->
        {section_kind, label} = match

        # Close previous section if open
        builder = end_section(builder, section_type)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new(@section_start_tags[section_kind], label))

        process_lines(rest, builder, section_kind, false)

      section_marker?(trimmed) ->
        # Unknown section marker → comment (matches JS behavior)
        [_, label] = Regex.run(@section_marker_regex, trimmed)
        builder = end_section(builder, section_type)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new("comment", label))

        process_lines(rest, builder, nil, false)

      chord_line?(line) ->
        {lyric_line, remaining} = pop_lyric_line(rest)
        pairs = pair_chords_and_lyrics(line, lyric_line)

        builder = SongBuilder.add_line(builder)

        builder =
          Enum.reduce(pairs, builder, fn pair, b ->
            SongBuilder.add_item(b, pair)
          end)

        process_lines(remaining, builder, section_type, false)

      true ->
        # Plain lyrics line
        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(ChordLyricsPair.new("", line))

        process_lines(rest, builder, section_type, false)
    end
  end

  # --- Section helpers ---

  defp end_section(builder, nil), do: builder

  defp end_section(builder, section_type) do
    end_tag_name = Map.fetch!(@section_end_tags, section_type)

    builder
    |> SongBuilder.add_line()
    |> SongBuilder.add_item(Tag.new(end_tag_name, ""))
  end

  defp parse_section_directive(trimmed) do
    cond do
      (m = Regex.run(@verse_regex, trimmed)) != nil -> {:verse, Enum.at(m, 1)}
      (m = Regex.run(@chorus_regex, trimmed)) != nil -> {:chorus, Enum.at(m, 1)}
      (m = Regex.run(@bridge_regex, trimmed)) != nil -> {:bridge, Enum.at(m, 1)}
      (m = Regex.run(@part_regex, trimmed)) != nil -> {:part, Enum.at(m, 1)}
      true -> nil
    end
  end

  defp section_marker?(str), do: Regex.match?(@section_marker_regex, str)

  defp pop_lyric_line([]), do: {nil, []}

  defp pop_lyric_line([next | rest]) do
    trimmed = String.trim(next)

    if trimmed == "" or chord_line?(next) or section_marker?(trimmed) do
      {nil, [next | rest]}
    else
      {next, rest}
    end
  end

  # --- Chord detection ---

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

  # --- Pairing ---

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
    regex = ~r/\S+/

    Regex.scan(regex, line, return: :index)
    |> Enum.flat_map(fn [{pos, len}] ->
      token = String.slice(line, pos, len)
      if chord_token?(token), do: [{token, pos}], else: []
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
    {_first_chord, first_pos} = hd(chord_positions)

    leading =
      if first_pos > 0 do
        [ChordLyricsPair.new("", safe_slice(lyric_line, 0, first_pos))]
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

        ChordLyricsPair.new(chord, safe_slice(lyric_line, pos, next_pos - pos))
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
end

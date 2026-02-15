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
    builder = process_lines(lines, SongBuilder.new())
    SongBuilder.build(builder)
  end

  defp split_lines(input) do
    input
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n")
  end

  @section_marker_regex ~r/^\[([^\]]+)\]\s*$/

  @section_map %{
    "verse" => "start_of_verse",
    "chorus" => "start_of_chorus",
    "bridge" => "start_of_bridge",
    "tab" => "start_of_tab",
    "intro" => "start_of_part",
    "outro" => "start_of_part",
    "pre-chorus" => "start_of_part",
    "interlude" => "start_of_part",
    "instrumental" => "start_of_part",
    "solo" => "start_of_part"
  }

  defp process_lines([], builder), do: builder

  defp process_lines([line | rest], builder) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        process_lines(rest, SongBuilder.add_line(builder))

      section_marker?(trimmed) ->
        [_, section_name] = Regex.run(@section_marker_regex, trimmed)
        tag_name = section_name_to_tag(section_name)
        tag = Tag.new(tag_name, section_name)

        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(tag)

        process_lines(rest, builder)

      chord_line?(line) ->
        {lyric_line, remaining} = pop_lyric_line(rest)
        pairs = pair_chords_and_lyrics(line, lyric_line)

        builder = SongBuilder.add_line(builder)

        builder =
          Enum.reduce(pairs, builder, fn pair, b ->
            SongBuilder.add_item(b, pair)
          end)

        process_lines(remaining, builder)

      true ->
        # Plain lyrics line
        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(ChordLyricsPair.new("", line))

        process_lines(rest, builder)
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
    tokens = String.split(trimmed)
    chord_count = Enum.count(tokens, &chord_token?/1)
    chord_count > 0 and chord_count / length(tokens) >= 0.5
  end

  defp chord_token?(token), do: Chord.parse(token) != nil

  # --- Pairing ---

  defp pair_chords_and_lyrics(chord_line, nil) do
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
    regex = ~r/\S+/

    Regex.scan(regex, line, return: :index)
    |> Enum.flat_map(fn [{pos, len}] ->
      token = String.slice(line, pos, len)
      if chord_token?(token), do: [{token, pos}], else: []
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

  defp section_name_to_tag(name) do
    lower = String.downcase(String.trim(name))
    base = Regex.replace(~r/\s*\d+$/, lower, "")
    Map.get(@section_map, base, "start_of_part")
  end
end

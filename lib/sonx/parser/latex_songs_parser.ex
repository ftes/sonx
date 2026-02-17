defmodule Sonx.Parser.LatexSongsParser do
  @moduledoc """
  Parses LaTeX songs package format into a Song struct.

  See https://songs.sourceforge.net/songsdoc/songs.html

  Supports:
  - `\\beginsong{Title \\\\ Subtitle}[by={Artist}]` -- song header
  - `\\beginverse` / `\\endverse` -- verse sections
  - `\\beginverse*` -- unnumbered verse (treated same as verse)
  - `\\beginchorus` / `\\endchorus` -- chorus sections
  - `\\[Chord]lyrics` -- inline chords
  - `\\capo{N}` -- capo tag
  - `\\textcomment{text}`, `\\textnote{text}`, `\\musicnote{text}` -- comments
  - `\\echo{content}` -- echo content (parsed as chord/lyrics)
  - LaTeX character unescaping

  Commands with no IR equivalent (memorize/replay, measure bars, guitar tabs,
  scripture blocks, index commands) are skipped gracefully.

  Example input:
      \\beginsong{Let It Be}[by={The Beatles}]
      \\beginverse
      \\[C]When I find myself in \\[G]times of trouble
      \\endverse
      \\endsong
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
      {:error, reason} -> raise "LaTeX songs parse error: #{reason}"
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

  # --- Line classification and processing ---

  @section_start_commands %{
    "\\beginverse" => "start_of_verse",
    "\\beginverse*" => "start_of_verse",
    "\\beginchorus" => "start_of_chorus"
  }

  @section_end_commands %{
    "\\endverse" => "end_of_verse",
    "\\endchorus" => "end_of_chorus"
  }

  @comment_commands ~w(\\textcomment \\textnote \\musicnote)

  @skip_prefixes ~w(
    \\transpose \\memorize \\replay \\rep \\lrep \\rrep
    \\nolyrics \\brk \\nextcol \\meter \\measurebar \\gtab
    \\sclearpage \\scleardpage \\noversenumbers \\nosongnumbers
    \\chordson \\chordsoff \\measureson \\measuresoff
    \\indexeson \\indexesoff \\scriptureon \\scriptureoff
    \\preferflats \\prefersharps \\solfedge \\alphascale
    \\newchords \\newindex \\newauthorindex \\newscripindex
    \\showindex \\indexentry \\indextitleentry
    \\MultiwordChords \\DeclareLyricChar \\DeclareNonLyric \\DeclareNoHyphen
    \\shrp \\flt \\setlicense \\includeonlysongs
    \\repchoruses \\norepchoruses \\songsection \\songchapter
  )

  defp classify_line(""), do: :empty
  defp classify_line("\\endsong"), do: :skip
  defp classify_line("\\end{songs}"), do: :skip
  defp classify_line("^"), do: :skip

  defp classify_line("\\beginsong" <> _ = line), do: {:header, line}

  defp classify_line(trimmed) when is_map_key(@section_start_commands, trimmed),
    do: {:tag, @section_start_commands[trimmed], ""}

  defp classify_line(trimmed) when is_map_key(@section_end_commands, trimmed),
    do: {:tag, @section_end_commands[trimmed], ""}

  defp classify_line("\\capo{" <> _ = line), do: {:tag, "capo", unescape(extract_brace_arg(line, "\\capo"))}
  defp classify_line("\\echo{" <> _ = line), do: {:echo, extract_brace_arg(line, "\\echo")}

  defp classify_line("\\beginscripture" <> _), do: {:skip_block, "\\endscripture"}
  defp classify_line("\\begin{intersong" <> _), do: {:skip_block, "\\end{intersong"}
  defp classify_line("\\begin{songs}" <> _), do: :skip
  defp classify_line("%" <> _), do: :skip

  defp classify_line(trimmed) do
    case find_comment_command(trimmed) do
      {_cmd, value} -> {:comment, value}
      nil -> if skip_line?(trimmed), do: :skip, else: {:content, trimmed}
    end
  end

  defp find_comment_command(trimmed) do
    Enum.find_value(@comment_commands, fn cmd ->
      if String.starts_with?(trimmed, cmd <> "{") do
        {cmd, extract_brace_arg(trimmed, cmd)}
      end
    end)
  end

  defp skip_line?(trimmed) do
    Enum.any?(@skip_prefixes, &String.starts_with?(trimmed, &1))
  end

  # --- Line processing ---

  defp process_lines([], builder), do: builder

  defp process_lines([line | rest], builder) do
    case classify_line(String.trim(line)) do
      :empty ->
        process_lines(rest, SongBuilder.add_line(builder))

      :skip ->
        process_lines(rest, builder)

      {:header, header_line} ->
        process_lines(rest, parse_header(builder, header_line))

      {:tag, tag_name, value} ->
        builder =
          builder
          |> SongBuilder.add_line()
          |> SongBuilder.add_item(Tag.new(tag_name, value))

        process_lines(rest, builder)

      {:comment, value} ->
        process_lines(rest, add_comment(builder, unescape(value)))

      {:echo, value} ->
        process_lines(rest, add_content(builder, value))

      {:skip_block, end_marker} ->
        process_lines(skip_until(rest, end_marker), builder)

      {:content, content} ->
        process_lines(rest, add_content(builder, content))
    end
  end

  # --- Header parsing ---

  @header_regex ~r/^\\beginsong\{(.+)\}(?:\[by=\{(.*?)\}\])?$/

  defp parse_header(builder, line) do
    case Regex.run(@header_regex, line) do
      [_, title_part] ->
        parse_header_parts(builder, title_part, "")

      [_, title_part, artist_part] ->
        parse_header_parts(builder, title_part, artist_part)

      _ ->
        builder
    end
  end

  defp parse_header_parts(builder, title_part, artist_part) do
    {title, subtitle} =
      case String.split(title_part, " \\\\ ", parts: 2) do
        [t, s] -> {unescape(String.trim(t)), unescape(String.trim(s))}
        [t] -> {unescape(String.trim(t)), nil}
      end

    builder =
      builder
      |> SongBuilder.add_line()
      |> SongBuilder.add_item(Tag.new("title", title))

    builder =
      if subtitle && subtitle != "" do
        builder
        |> SongBuilder.add_line()
        |> SongBuilder.add_item(Tag.new("subtitle", subtitle))
      else
        builder
      end

    artist = unescape(String.trim(artist_part))

    if artist == "" do
      builder
    else
      builder
      |> SongBuilder.add_line()
      |> SongBuilder.add_item(Tag.new("artist", artist))
    end
  end

  # --- Content helpers ---

  defp add_content(builder, content) do
    pairs = parse_content_line(content)
    builder = SongBuilder.add_line(builder)

    Enum.reduce(pairs, builder, fn pair, b ->
      SongBuilder.add_item(b, pair)
    end)
  end

  defp add_comment(builder, text) do
    builder
    |> SongBuilder.add_line()
    |> SongBuilder.add_item(Tag.new("comment", text))
  end

  # --- Brace argument extraction ---

  defp extract_brace_arg(line, prefix) do
    rest = String.trim_leading(line, prefix)

    case Regex.run(~r/^\{(.*)\}$/, rest) do
      [_, content] -> content
      _ -> ""
    end
  end

  # --- Skip helpers ---

  defp skip_until([], _end_marker), do: []

  defp skip_until([line | rest], end_marker) do
    if String.starts_with?(String.trim(line), end_marker) do
      rest
    else
      skip_until(rest, end_marker)
    end
  end

  # --- Content line parsing ---

  @chord_regex ~r/\\\[([^\]]+)\]/

  defp parse_content_line(line) do
    line
    |> split_on_chords()
    |> build_pairs()
  end

  defp split_on_chords(line) do
    parts = Regex.split(@chord_regex, line, include_captures: true)

    Enum.map(parts, fn part ->
      case Regex.run(@chord_regex, part) do
        [_, chord_name] -> {:chord, chord_name}
        _ -> {:text, unescape(part)}
      end
    end)
  end

  defp build_pairs(segments) do
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
    do_build_pairs(rest, nil, [ChordLyricsPair.new(current_chord, text) | acc])
  end

  defp do_build_pairs([{:chord, chord} | rest], nil, acc) do
    do_build_pairs(rest, chord, acc)
  end

  defp do_build_pairs([{:chord, chord} | rest], current_chord, acc) do
    do_build_pairs(rest, chord, [ChordLyricsPair.new(current_chord, "") | acc])
  end

  # --- LaTeX unescaping ---
  # Order matters: multi-char sequences (\textbackslash{}, \textasciitilde{},
  # \textasciicircum{}) must be handled before \{ and \} to avoid corruption.

  defp unescape(str) when is_binary(str) do
    str
    |> String.replace("\\textbackslash{}", "\\")
    |> String.replace("\\textasciitilde{}", "~")
    |> String.replace("\\textasciicircum{}", "^")
    |> String.replace("\\&", "&")
    |> String.replace("\\%", "%")
    |> String.replace("\\$", "$")
    |> String.replace("\\#", "#")
    |> String.replace("\\_", "_")
    |> String.replace("\\{", "{")
    |> String.replace("\\}", "}")
  end

  defp unescape(nil), do: ""
end

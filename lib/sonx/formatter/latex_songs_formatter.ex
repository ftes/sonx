defmodule Sonx.Formatter.LatexSongsFormatter do
  @moduledoc """
  Formats a Song as a LaTeX file for the songs package.

  See http://songs.sourceforge.net/docs.html

  Example output:
      \\beginsong{My Song}[by={Artist}]
      \\beginverse
      \\[Am]Hello \\[G]world
      \\endverse
      \\endsong
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

  @header_tags [Tags.title(), Tags.subtitle(), Tags.artist()]

  @impl true
  @spec format(Song.t(), keyword()) :: String.t()
  def format(%Song{} = song, opts \\ []) do
    metadata = Song.metadata(song)

    header = format_header(song)
    body = format_body(song, metadata, opts)

    [header, body, "\\endsong"]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # --- Header ---

  defp format_header(song) do
    title = escape(Song.title(song) || "")
    subtitle = Song.subtitle(song)

    title_str =
      if subtitle && subtitle != "" do
        "#{title} \\\\ #{escape(subtitle)}"
      else
        title
      end

    artist =
      song
      |> Song.metadata()
      |> Metadata.get("artist")
      |> case do
        nil -> ""
        values when is_list(values) -> Enum.map_join(values, ", ", &escape/1)
        value -> escape(value)
      end

    "\\beginsong{#{title_str}}[by={#{artist}}]"
  end

  # --- Body ---

  defp format_body(%Song{lines: lines}, metadata, opts) do
    {formatted, open_section} =
      Enum.reduce(lines, {[], nil}, fn line, {acc, open} ->
        section_start = line_section_start(line)

        acc =
          if section_start && open do
            [close_command(open) | acc]
          else
            acc
          end

        open =
          cond do
            section_start -> section_start
            line_section_end?(line) -> nil
            true -> open
          end

        {[format_line(line, metadata, opts) | acc], open}
      end)

    formatted =
      if open_section do
        [close_command(open_section) | formatted]
      else
        formatted
      end

    formatted
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp line_section_start(%Line{items: [%Tag{name: name}]}) do
    if Tags.section_start?(name), do: name
  end

  defp line_section_start(_), do: nil

  defp line_section_end?(%Line{items: [%Tag{name: name}]}), do: Tags.section_end?(name)
  defp line_section_end?(_), do: false

  @close_commands %{
    "start_of_verse" => "\\endverse",
    "start_of_chorus" => "\\endchorus",
    "start_of_bridge" => "\\endverse",
    "start_of_tab" => "\\endverse",
    "start_of_grid" => "\\endverse",
    "start_of_part" => "\\endverse"
  }

  defp close_command(section_start_name) do
    Map.get(@close_commands, section_start_name, "\\endverse")
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
    chord_part <> escape(lyrics)
  end

  defp format_item(%Tag{} = tag, _metadata, _opts) do
    format_tag(tag)
  end

  defp format_item(%Comment{content: content}, _metadata, _opts) do
    "\\textcomment{#{escape(content)}}"
  end

  defp format_item(%SoftLineBreak{}, _metadata, _opts) do
    " "
  end

  defp format_item(%Ternary{} = ternary, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      escape(Evaluatable.evaluate(ternary, metadata))
    else
      ""
    end
  end

  defp format_item(%Literal{} = literal, metadata, opts) do
    if Keyword.get(opts, :evaluate, false) do
      escape(Evaluatable.evaluate(literal, metadata))
    else
      escape(literal.string)
    end
  end

  # --- Chord formatting ---

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

    "\\[#{chord_str}]"
  end

  # --- Tag formatting ---

  @section_commands %{
    "start_of_verse" => "\\beginverse",
    "end_of_verse" => "\\endverse",
    "start_of_chorus" => "\\beginchorus",
    "end_of_chorus" => "\\endchorus"
  }

  defp format_tag(%Tag{name: name}) when name in @header_tags, do: ""
  defp format_tag(%Tag{name: name}) when is_map_key(@section_commands, name), do: @section_commands[name]
  defp format_tag(%Tag{name: "comment", value: value}), do: "\\textcomment{#{escape(value)}}"
  defp format_tag(%Tag{name: "capo", value: value}), do: "\\capo{#{escape(value)}}"

  defp format_tag(%Tag{name: name, value: value} = tag) do
    cond do
      Tags.section_start?(name) or Tags.section_end?(name) -> ""
      Tags.meta_tag?(name) -> ""
      Tag.has_value?(tag) -> "\\textcomment{#{escape(name)}: #{escape(value)}}"
      true -> "\\textcomment{#{escape(name)}}"
    end
  end

  # --- LaTeX escaping ---

  defp escape(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\textbackslash{}")
    |> String.replace("&", "\\&")
    |> String.replace("%", "\\%")
    |> String.replace("$", "\\$")
    |> String.replace("#", "\\#")
    |> String.replace("_", "\\_")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("~", "\\textasciitilde{}")
    |> String.replace("^", "\\textasciicircum{}")
  end

  defp escape(nil), do: ""
end

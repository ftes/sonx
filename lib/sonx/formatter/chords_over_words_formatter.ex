defmodule Sonx.Formatter.ChordsOverWordsFormatter do
  @moduledoc """
  Formats a Song as chords-over-words plain text with a metadata header.

  Example output:
      title: My Song
      artist: John Doe

      Am       C           G
      This is  some lyrics here
  """

  @behaviour Sonx.Formatter

  alias Sonx.{Chord, Evaluatable}

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    Metadata,
    Paragraph,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  alias Sonx.Formatter.Html

  @meta_order ~w(title subtitle artist composer lyricist album year key tempo time capo duration)

  @impl true
  @spec format(Song.t(), keyword()) :: String.t()
  def format(%Song{} = song, opts \\ []) do
    metadata = Song.metadata(song)

    header = format_header(metadata)
    body = format_paragraphs(song, metadata, opts)

    [header, body]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  # --- Header ---

  defp format_header(%Metadata{} = metadata) do
    lines =
      @meta_order
      |> Enum.flat_map(fn key ->
        case Metadata.get(metadata, key) do
          nil ->
            []

          values when is_list(values) ->
            [{key, Enum.join(values, ", ")}]

          value ->
            [{key, value}]
        end
      end)
      |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)

    case lines do
      [] -> ""
      _ -> Enum.join(["---" | lines] ++ ["---"], "\n")
    end
  end

  # --- Paragraphs ---

  defp format_paragraphs(song, metadata, opts) do
    song
    |> Song.body_paragraphs()
    |> Enum.map(&format_paragraph(&1, metadata, opts))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp format_paragraph(%Paragraph{} = paragraph, metadata, opts) do
    if Paragraph.literal?(paragraph) do
      format_literal_paragraph(paragraph)
    else
      paragraph.lines
      |> Enum.filter(&Line.has_renderable_items?/1)
      |> Enum.map(&format_line(&1, metadata, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end
  end

  defp format_literal_paragraph(paragraph) do
    paragraph.lines
    |> Enum.flat_map(fn line ->
      Enum.map(line.items, fn
        %ChordLyricsPair{lyrics: lyrics} -> lyrics || ""
        _ -> ""
      end)
    end)
    |> Enum.join("\n")
  end

  # --- Lines ---

  defp format_line(%Line{} = line, metadata, opts) do
    top = format_line_top(line, metadata, opts)
    bottom = format_line_bottom(line, metadata, opts)

    [top, bottom]
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp format_line_top(%Line{} = line, metadata, opts) do
    if Html.has_chord_contents?(line) do
      line.items
      |> Enum.map(&format_item_top(&1, line, metadata, opts))
      |> IO.iodata_to_binary()
    else
      ""
    end
  end

  defp format_line_bottom(%Line{} = line, metadata, opts) do
    if has_text_contents?(line) do
      line.items
      |> Enum.map(&format_item_bottom(&1, line, metadata, opts))
      |> IO.iodata_to_binary()
    else
      ""
    end
  end

  # --- Item formatting (top = chords, bottom = lyrics) ---

  defp format_item_top(%ChordLyricsPair{} = pair, line, _metadata, opts) do
    content = render_chord_content(pair, opts)
    pad_right(content, pair_length(pair, line, opts))
  end

  defp format_item_top(%Tag{} = tag, _line, _metadata, _opts) do
    if Tag.renderable?(tag), do: Tag.label(tag), else: ""
  end

  defp format_item_top(%Ternary{}, _line, _metadata, _opts), do: ""
  defp format_item_top(%Literal{}, _line, _metadata, _opts), do: ""
  defp format_item_top(%Comment{}, _line, _metadata, _opts), do: ""

  defp format_item_top(%SoftLineBreak{}, _line, _metadata, _opts) do
    "  "
  end

  defp format_item_bottom(%ChordLyricsPair{lyrics: lyrics} = pair, line, _metadata, opts) do
    pad_right(lyrics || "", pair_length(pair, line, opts))
  end

  defp format_item_bottom(%Tag{} = tag, _line, _metadata, _opts) do
    if Tag.renderable?(tag), do: Tag.label(tag), else: ""
  end

  defp format_item_bottom(%Ternary{} = ternary, _line, metadata, _opts) do
    Evaluatable.evaluate(ternary, metadata)
  end

  defp format_item_bottom(%Literal{} = literal, _line, metadata, _opts) do
    Evaluatable.evaluate(literal, metadata)
  end

  defp format_item_bottom(%Comment{}, _line, _metadata, _opts), do: ""

  defp format_item_bottom(%SoftLineBreak{}, _line, _metadata, _opts) do
    "\\ "
  end

  # --- Alignment ---

  defp pair_length(%ChordLyricsPair{} = pair, _line, opts) do
    content = render_chord_content(pair, opts)
    content_len = String.length(content)
    lyrics_len = String.length(pair.lyrics || "")

    if content_len >= lyrics_len do
      content_len + 1
    else
      max(content_len, lyrics_len)
    end
  end

  defp render_chord_content(%ChordLyricsPair{annotation: ann}, _opts) when is_binary(ann) and ann != "" do
    ann
  end

  defp render_chord_content(%ChordLyricsPair{chords: chords}, opts) do
    unicode_accidentals? = Keyword.get(opts, :unicode_accidentals, false)

    case Chord.parse(chords || "") do
      nil -> chords || ""
      chord -> Chord.to_string(chord, unicode_accidentals: unicode_accidentals?)
    end
  end

  defp pad_right(str, length) do
    str_len = String.length(str)

    if str_len < length do
      str <> String.duplicate(" ", length - str_len)
    else
      str
    end
  end

  defp has_text_contents?(%Line{items: items}) do
    Enum.any?(items, fn
      %ChordLyricsPair{lyrics: l} when is_binary(l) and l != "" -> true
      %Tag{} = tag -> Tag.renderable?(tag)
      %Ternary{} -> true
      %Literal{} -> true
      _ -> false
    end)
  end
end

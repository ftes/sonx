defmodule Sonx.Formatter.HtmlTableFormatter do
  @moduledoc """
  Formats a Song as HTML using `<table>` elements.

  Example output structure:
      <h1 class="title">Song Title</h1>
      <div class="chord-sheet">
        <div class="paragraph verse">
          <table class="row">
            <tr>
              <td class="chord">C</td>
              <td class="chord">G</td>
            </tr>
            <tr>
              <td class="lyrics">Hello </td>
              <td class="lyrics">world</td>
            </tr>
          </table>
        </div>
      </div>
  """

  @behaviour Sonx.Formatter

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    Paragraph,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  alias Sonx.Formatter.Html

  @doc """
  Returns default CSS for the HTML table output.
  """
  @spec css_string() :: String.t()
  def css_string do
    css = Html.default_css_classes()

    Html.render_css([
      {".#{css.title}", [{"font-size", "1.5em"}]},
      {".#{css.subtitle}", [{"font-size", "1.1em"}]},
      {".#{css.row}, .#{css.line}, .#{css.literal}", [{"border-spacing", "0"}, {"color", "inherit"}]},
      {".#{css.annotation}, .#{css.chord}, .#{css.comment}, .#{css.literal_contents}, .#{css.label_wrapper}, .#{css.literal}, .#{css.lyrics}",
       [{"padding", "3px 0"}]},
      {".#{css.chord}:not(:last-child)", [{"padding-right", "10px"}]},
      {".#{css.paragraph}", [{"margin-bottom", "1em"}]}
    ])
  end

  @impl true
  @spec format(Song.t(), keyword()) :: String.t()
  def format(%Song{} = song, opts \\ []) do
    css = Html.css_classes(opts)
    metadata = Song.metadata(song)

    header = Html.format_header(song, css)

    body =
      song
      |> Song.body_paragraphs()
      |> Enum.map(&format_paragraph(&1, metadata, css, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    sheet_content =
      if body == "" do
        ""
      else
        "<div class=\"#{css.chord_sheet}\">\n#{body}\n</div>"
      end

    [header, sheet_content]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # --- Paragraphs ---

  defp format_paragraph(%Paragraph{} = paragraph, metadata, css, opts) do
    classes = Html.paragraph_classes(paragraph, css)

    if Paragraph.literal?(paragraph) do
      format_literal_paragraph(paragraph, css, classes)
    else
      tables =
        paragraph.lines
        |> Enum.filter(&Html.line_has_contents?/1)
        |> Enum.map(&format_line(&1, metadata, css, opts))
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      if tables == "" do
        ""
      else
        "<div class=\"#{classes}\">\n#{tables}\n</div>"
      end
    end
  end

  defp format_literal_paragraph(paragraph, css, classes) do
    content =
      paragraph.lines
      |> Enum.flat_map(fn line ->
        Enum.map(line.items, fn
          %ChordLyricsPair{lyrics: lyrics} -> Html.escape(lyrics || "")
          _ -> ""
        end)
      end)
      |> Enum.join("<br>")

    label_html =
      case Paragraph.label(paragraph) do
        nil ->
          ""

        "" ->
          ""

        lbl ->
          "<table class=\"#{css.row}\"><tr><td class=\"#{css.label_wrapper}\"><h3 class=\"#{css.label}\">#{Html.escape(lbl)}</h3></td></tr></table>\n"
      end

    "<div class=\"#{classes}\">\n#{label_html}<table class=\"#{css.literal}\"><tr><td class=\"#{css.literal_contents}\">#{content}</td></tr></table>\n</div>"
  end

  # --- Lines ---

  defp format_line(%Line{} = line, metadata, css, opts) do
    {chord_cells, lyric_cells, label_html} = build_cells(line, metadata, css, opts)

    cond do
      label_html != "" ->
        # Label-only line
        "<table class=\"#{css.row}\"><tr><td class=\"#{css.label_wrapper}\">#{label_html}</td></tr></table>"

      chord_cells == [] and lyric_cells == [] ->
        ""

      true ->
        rows = []

        rows =
          if Html.has_chord_contents?(line) do
            rows ++ ["<tr>\n#{Enum.join(chord_cells, "\n")}\n</tr>"]
          else
            rows
          end

        rows =
          if Html.has_text_contents?(line) or not Html.has_chord_contents?(line) do
            rows ++ ["<tr>\n#{Enum.join(lyric_cells, "\n")}\n</tr>"]
          else
            rows
          end

        "<table class=\"#{css.row}\">\n#{Enum.join(rows, "\n")}\n</table>"
    end
  end

  defp build_cells(%Line{items: items}, metadata, css, opts) do
    Enum.reduce(items, {[], [], ""}, fn item, acc ->
      build_cell(item, acc, metadata, css, opts)
    end)
  end

  defp build_cell(%ChordLyricsPair{} = pair, {ch, ly, lbl}, _metadata, css, opts) do
    chord_class = if pair.annotation && pair.annotation != "", do: css.annotation, else: css.chord
    chord_content = chord_or_annotation(pair, opts)
    lyric_content = Html.escape(pair.lyrics || "")

    {
      ch ++ ["<td class=\"#{chord_class}\">#{chord_content}</td>"],
      ly ++ ["<td class=\"#{css.lyrics}\">#{lyric_content}</td>"],
      lbl
    }
  end

  defp build_cell(%Tag{} = tag, {ch, ly, lbl}, _metadata, css, _opts) do
    cond do
      Tag.comment?(tag) ->
        {ch, ly ++ ["<td class=\"#{css.comment}\">#{Html.escape(Tag.label(tag))}</td>"], lbl}

      Tag.has_renderable_label?(tag) ->
        {ch, ly, Html.render_label(tag, css)}

      true ->
        {ch, ly, lbl}
    end
  end

  defp build_cell(%Comment{} = comment, {ch, ly, lbl}, _metadata, css, _opts) do
    {ch, ly ++ ["<td class=\"#{css.comment}\">#{Html.escape(comment.content)}</td>"], lbl}
  end

  defp build_cell(%Ternary{} = ternary, {ch, ly, lbl}, metadata, css, _opts) do
    {ch, ly ++ ["<td class=\"#{css.lyrics}\">#{Html.evaluate_item(ternary, metadata)}</td>"], lbl}
  end

  defp build_cell(%Literal{} = literal, {ch, ly, lbl}, metadata, css, _opts) do
    {ch, ly ++ ["<td class=\"#{css.lyrics}\">#{Html.evaluate_item(literal, metadata)}</td>"], lbl}
  end

  defp build_cell(%SoftLineBreak{}, acc, _metadata, _css, _opts), do: acc

  # --- Helpers ---

  defp chord_or_annotation(%ChordLyricsPair{annotation: ann}, _opts) when is_binary(ann) and ann != "" do
    Html.escape(ann)
  end

  defp chord_or_annotation(%ChordLyricsPair{chords: chords}, opts) do
    Html.render_chord(chords, opts)
  end
end

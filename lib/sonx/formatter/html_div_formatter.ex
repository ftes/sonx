defmodule Sonx.Formatter.HtmlDivFormatter do
  @moduledoc """
  Formats a Song as HTML using nested `<div>` elements with flexbox layout.

  Example output structure:
      <h1 class="title">Song Title</h1>
      <div class="chord-sheet">
        <div class="paragraph verse">
          <div class="row">
            <div class="column">
              <div class="chord">C</div>
              <div class="lyrics">Hello </div>
            </div>
          </div>
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
      rows =
        paragraph.lines
        |> Enum.filter(&Html.line_has_contents?/1)
        |> Enum.map(&format_line(&1, metadata, css, opts))
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      if rows == "" do
        ""
      else
        "<div class=\"#{classes}\">\n#{rows}\n</div>"
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
          "<div class=\"#{css.row}\"><h3 class=\"#{css.label}\">#{Html.escape(lbl)}</h3></div>\n"
      end

    "<div class=\"#{classes}\">\n#{label_html}<div class=\"#{css.row}\"><div class=\"#{css.literal}\">#{content}</div></div>\n</div>"
  end

  # --- Lines ---

  defp format_line(%Line{} = line, metadata, css, opts) do
    columns =
      line.items
      |> Enum.map(&format_item(&1, metadata, css, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    if columns == "" do
      ""
    else
      "<div class=\"#{css.row}\">\n#{columns}\n</div>"
    end
  end

  # --- Items ---

  defp format_item(%ChordLyricsPair{} = pair, _metadata, css, opts) do
    chord_content = chord_or_annotation(pair, opts)
    lyrics = Html.escape(pair.lyrics || "")

    chord_class =
      if pair.annotation && pair.annotation != "", do: css.annotation, else: css.chord

    chord_html = "<div class=\"#{chord_class}\">#{chord_content}</div>"

    "<div class=\"#{css.column}\">" <>
      chord_html <>
      "<div class=\"#{css.lyrics}\">#{lyrics}</div>" <>
      "</div>"
  end

  defp format_item(%Tag{} = tag, _metadata, css, _opts) do
    cond do
      Tag.comment?(tag) ->
        "<div class=\"#{css.comment}\">#{Html.escape(Tag.label(tag))}</div>"

      Tag.has_renderable_label?(tag) ->
        Html.render_label(tag, css)

      true ->
        ""
    end
  end

  defp format_item(%Comment{} = comment, _metadata, css, _opts) do
    Html.render_comment(comment, css)
  end

  defp format_item(%Ternary{} = ternary, metadata, css, _opts) do
    evaluated = Html.evaluate_item(ternary, metadata)

    "<div class=\"#{css.column}\">" <>
      "<div class=\"#{css.chord}\"></div>" <>
      "<div class=\"#{css.lyrics}\">#{evaluated}</div>" <>
      "</div>"
  end

  defp format_item(%Literal{} = literal, metadata, css, _opts) do
    evaluated = Html.evaluate_item(literal, metadata)

    "<div class=\"#{css.column}\">" <>
      "<div class=\"#{css.chord}\"></div>" <>
      "<div class=\"#{css.lyrics}\">#{evaluated}</div>" <>
      "</div>"
  end

  defp format_item(%SoftLineBreak{}, _metadata, _css, _opts), do: ""

  # --- Helpers ---

  defp chord_or_annotation(%ChordLyricsPair{annotation: ann}, _opts) when is_binary(ann) and ann != "" do
    Html.escape(ann)
  end

  defp chord_or_annotation(%ChordLyricsPair{chords: chords}, opts) do
    Html.render_chord(chords, opts)
  end
end

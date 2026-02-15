defmodule Sonx.Formatter.Html do
  @moduledoc """
  Shared utilities for HTML formatters.

  Provides CSS class handling, chord rendering, and common HTML generation
  used by both HtmlDivFormatter and HtmlTableFormatter.
  """

  alias Sonx.{Chord, Evaluatable}

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    Paragraph,
    Song,
    Tag,
    Ternary
  }

  alias Sonx.ChordSheet.Metadata

  @type css_classes :: %{
          annotation: String.t(),
          chord: String.t(),
          chord_sheet: String.t(),
          column: String.t(),
          comment: String.t(),
          empty_line: String.t(),
          label: String.t(),
          label_wrapper: String.t(),
          line: String.t(),
          literal: String.t(),
          literal_contents: String.t(),
          lyrics: String.t(),
          paragraph: String.t(),
          row: String.t(),
          subtitle: String.t(),
          title: String.t()
        }

  @default_css_classes %{
    annotation: "annotation",
    chord: "chord",
    chord_sheet: "chord-sheet",
    column: "column",
    comment: "comment",
    empty_line: "empty-line",
    label: "label",
    label_wrapper: "label-wrapper",
    line: "line",
    literal: "literal",
    literal_contents: "contents",
    lyrics: "lyrics",
    paragraph: "paragraph",
    row: "row",
    subtitle: "subtitle",
    title: "title"
  }

  @spec default_css_classes() :: css_classes()
  def default_css_classes, do: @default_css_classes

  @spec css_classes(keyword()) :: css_classes()
  def css_classes(opts) do
    custom = Keyword.get(opts, :css_classes, %{})
    Map.merge(@default_css_classes, custom)
  end

  @spec format_header(Song.t(), css_classes()) :: String.t()
  def format_header(song, css) do
    parts = []

    parts =
      case Song.title(song) do
        nil -> parts
        "" -> parts
        title -> parts ++ ["<h1 class=\"#{css.title}\">#{escape(title)}</h1>"]
      end

    parts =
      case Song.subtitle(song) do
        nil -> parts
        "" -> parts
        sub -> parts ++ ["<h2 class=\"#{css.subtitle}\">#{escape(sub)}</h2>"]
      end

    Enum.join(parts, "\n")
  end

  @spec paragraph_classes(Paragraph.t(), css_classes()) :: String.t()
  def paragraph_classes(%Paragraph{} = paragraph, css) do
    type = Paragraph.type(paragraph)

    if type != :none and type != :indeterminate do
      "#{css.paragraph} #{type}"
    else
      css.paragraph
    end
  end

  @doc "Returns true if a line has any visible content for HTML rendering (includes comments)."
  @spec line_has_contents?(Line.t()) :: boolean()
  def line_has_contents?(%Line{items: items}) do
    Enum.any?(items, fn
      %ChordLyricsPair{} -> true
      %Comment{} -> true
      %Ternary{} -> true
      %Literal{} -> true
      %Tag{} = tag -> Tag.renderable?(tag)
      _ -> false
    end)
  end

  @spec has_chord_contents?(Line.t()) :: boolean()
  def has_chord_contents?(%Line{items: items}) do
    Enum.any?(items, fn
      %ChordLyricsPair{chords: c} when is_binary(c) and c != "" -> true
      %ChordLyricsPair{annotation: a} when is_binary(a) and a != "" -> true
      _ -> false
    end)
  end

  @spec has_text_contents?(Line.t()) :: boolean()
  def has_text_contents?(%Line{items: items}) do
    Enum.any?(items, fn
      %ChordLyricsPair{lyrics: l} when is_binary(l) and l != "" -> true
      %Ternary{} -> true
      %Literal{} -> true
      _ -> false
    end)
  end

  @spec render_chord(String.t(), keyword()) :: String.t()
  def render_chord(chord_str, opts \\ []) do
    unicode_accidentals? = Keyword.get(opts, :unicode_accidentals, false)

    case Chord.parse(chord_str || "") do
      nil -> escape(chord_str || "")
      chord -> escape(Chord.to_string(chord, unicode_accidentals: unicode_accidentals?))
    end
  end

  @spec render_item_chord(ChordLyricsPair.t(), css_classes(), keyword()) :: String.t()
  def render_item_chord(%ChordLyricsPair{annotation: ann}, css, _opts) when is_binary(ann) and ann != "" do
    "<span class=\"#{css.annotation}\">#{escape(ann)}</span>"
  end

  def render_item_chord(%ChordLyricsPair{chords: chords}, css, opts) do
    "<span class=\"#{css.chord}\">#{render_chord(chords, opts)}</span>"
  end

  @spec render_item_lyrics(ChordLyricsPair.t(), css_classes()) :: String.t()
  def render_item_lyrics(%ChordLyricsPair{lyrics: lyrics}, css) do
    "<span class=\"#{css.lyrics}\">#{escape(lyrics || "")}</span>"
  end

  @spec render_comment(Comment.t(), css_classes()) :: String.t()
  def render_comment(%Comment{content: content}, css) do
    "<div class=\"#{css.comment}\">#{escape(content)}</div>"
  end

  @spec render_label(Tag.t(), css_classes()) :: String.t()
  def render_label(%Tag{} = tag, css) do
    "<h3 class=\"#{css.label}\">#{escape(Tag.label(tag))}</h3>"
  end

  @spec evaluate_item(Sonx.ChordSheet.item(), Metadata.t()) ::
          String.t()
  def evaluate_item(%Ternary{} = t, metadata), do: escape(Evaluatable.evaluate(t, metadata))
  def evaluate_item(%Literal{} = l, metadata), do: escape(Evaluatable.evaluate(l, metadata))
  def evaluate_item(_, _), do: ""

  @spec escape(String.t()) :: String.t()
  def escape(nil), do: ""

  def escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end

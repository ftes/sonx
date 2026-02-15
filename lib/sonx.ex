defmodule Sonx do
  @moduledoc """
  Elixir library for parsing and formatting chord sheets.

  Supports multiple input formats:
  - `:chord_pro` — ChordPro format with inline chords `[Am]lyrics` and directives `{title: ...}`
  - `:chords_over_words` — Plain text with chords on one line, lyrics below
  - `:ultimate_guitar` — Ultimate Guitar format with `[Verse]`/`[Chorus]` section markers

  And multiple output formats:
  - `:text` — Plain text with chords aligned above lyrics
  - `:chord_pro` — ChordPro format
  - `:chords_over_words` — Chords-over-words with metadata header
  - `:html_div` — HTML using flexbox `<div>` elements
  - `:html_table` — HTML using `<table>` elements

  ## Quick Start

      # Parse a ChordPro string
      {:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\\n[Am]Hello [G]world")

      # Format as plain text
      text = Sonx.format(:text, song)

      # Transpose up 3 semitones
      transposed = Sonx.transpose(song, 3)

      # Change key
      in_g = Sonx.change_key(song, "G")

      # Serialize to JSON
      json = Sonx.to_json(song)
      {:ok, restored} = Sonx.from_json(json)
  """

  alias Sonx.ChordSheet.Metadata
  alias Sonx.ChordSheet.Song

  alias Sonx.Formatter.{
    ChordProFormatter,
    ChordsOverWordsFormatter,
    HtmlDivFormatter,
    HtmlTableFormatter,
    TextFormatter
  }

  alias Sonx.Key

  alias Sonx.Parser.{
    ChordProParser,
    ChordsOverWordsParser,
    UltimateGuitarParser
  }

  alias Sonx.Serializer

  @type parser_format() :: :chord_pro | :chords_over_words | :ultimate_guitar
  @type formatter_format() :: :text | :chord_pro | :chords_over_words | :html_div | :html_table

  # --- Parsing ---

  @doc """
  Parses a chord sheet string in the given format into a Song.

  ## Examples

      {:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\\n[Am]Hello")
      {:ok, song} = Sonx.parse(:chords_over_words, "Am\\nHello")
      {:ok, song} = Sonx.parse(:ultimate_guitar, "[Verse]\\nAm\\nHello")
  """
  @spec parse(parser_format(), String.t(), keyword()) :: {:ok, Song.t()} | {:error, term()}
  def parse(format, input, opts \\ [])

  def parse(:chord_pro, input, opts), do: ChordProParser.parse(input, opts)
  def parse(:chords_over_words, input, opts), do: ChordsOverWordsParser.parse(input, opts)
  def parse(:ultimate_guitar, input, opts), do: UltimateGuitarParser.parse(input, opts)

  @doc """
  Parses a chord sheet string, raising on error.
  """
  @spec parse!(parser_format(), String.t(), keyword()) :: Song.t()
  def parse!(format, input, opts \\ []) do
    case parse(format, input, opts) do
      {:ok, song} -> song
      {:error, reason} -> raise "Parse error (#{format}): #{reason}"
    end
  end

  # --- Formatting ---

  @doc """
  Formats a Song into a string in the given output format.

  ## Options

  - `:unicode_accidentals` — Use unicode accidentals ♯/♭ instead of #/b (default: false)
  - `:normalize_chords` — Normalize chord formatting (default: false)
  - `:evaluate` — Evaluate ternary meta expressions (default: false)
  - `:css_classes` — Custom CSS class map (HTML formatters only)

  ## Examples

      text = Sonx.format(:text, song)
      html = Sonx.format(:html_div, song, css_classes: %{chord: "my-chord"})
  """
  @spec format(formatter_format(), Song.t(), keyword()) :: String.t()
  def format(format, song, opts \\ [])

  def format(:text, song, opts), do: TextFormatter.format(song, opts)
  def format(:chord_pro, song, opts), do: ChordProFormatter.format(song, opts)
  def format(:chords_over_words, song, opts), do: ChordsOverWordsFormatter.format(song, opts)
  def format(:html_div, song, opts), do: HtmlDivFormatter.format(song, opts)
  def format(:html_table, song, opts), do: HtmlTableFormatter.format(song, opts)

  # --- Chord Operations ---

  @doc """
  Transposes the song by the given number of semitones.

  ## Examples

      transposed = Sonx.transpose(song, 3)   # up 3 semitones
      transposed = Sonx.transpose(song, -2)   # down 2 semitones
  """
  @spec transpose(Song.t(), integer(), keyword()) :: Song.t()
  defdelegate transpose(song, delta, opts \\ []), to: Song

  @doc """
  Changes the song key to the target key, transposing all chords accordingly.

  Requires the song to have a key directive set.
  """
  @spec change_key(Song.t(), String.t() | Key.t()) :: Song.t()
  defdelegate change_key(song, new_key), to: Song

  @doc """
  Switches all chords in the song to use the given accidental (`:sharp` or `:flat`).
  """
  @spec use_accidental(Song.t(), Key.accidental()) :: Song.t()
  defdelegate use_accidental(song, accidental), to: Song

  # --- Metadata ---

  @doc "Returns the song's metadata."
  @spec metadata(Song.t()) :: Metadata.t()
  defdelegate metadata(song), to: Song

  @doc "Returns the song title, or nil."
  @spec title(Song.t()) :: String.t() | nil
  defdelegate title(song), to: Song

  @doc "Returns the song key, or nil."
  @spec key(Song.t()) :: String.t() | nil
  defdelegate key(song), to: Song

  @doc "Returns all unique chord strings in the song."
  @spec get_chords(Song.t()) :: [String.t()]
  defdelegate get_chords(song), to: Song

  # --- Serialization ---

  @doc "Serializes a Song to a map."
  @spec serialize(Song.t()) :: map()
  defdelegate serialize(song), to: Serializer

  @doc "Deserializes a map back to a Song."
  @spec deserialize(map()) :: {:ok, Song.t()} | {:error, term()}
  defdelegate deserialize(map), to: Serializer

  @doc "Serializes a Song to a JSON string."
  @spec to_json(Song.t()) :: String.t()
  defdelegate to_json(song), to: Serializer

  @doc "Deserializes a JSON string back to a Song."
  @spec from_json(String.t()) :: {:ok, Song.t()} | {:error, term()}
  defdelegate from_json(json), to: Serializer
end

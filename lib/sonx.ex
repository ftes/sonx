defmodule Sonx do
  @moduledoc """
  Main entry point for parsing and formatting chord sheets.

  See the [README](README.md) for supported formats, installation, and usage examples.

  ## Examples

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\\n{key: C}\\n[Am]Hello [G]world")
      iex> Sonx.title(song)
      "My Song"
      iex> Sonx.get_chords(song)
      ["Am", "G"]
      iex> Sonx.format(:text, song)
      "My Song\\n\\nAm    G\\nHello world"

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{key: C}\\n[Am]Hello [G]world")
      iex> transposed = Sonx.transpose(song, 3)
      iex> Sonx.get_chords(transposed)
      ["Cm", "A#"]
      iex> changed = Sonx.change_key(song, "G")
      iex> Sonx.get_chords(changed)
      ["Em", "D"]

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{title: Test}\\n[Am]Hello")
      iex> json = Sonx.to_json(song)
      iex> {:ok, restored} = Sonx.from_json(json)
      iex> Sonx.title(restored)
      "Test"
  """

  alias Sonx.ChordSheet.Metadata
  alias Sonx.ChordSheet.Song

  alias Sonx.Formatter.{
    ChordProFormatter,
    ChordsOverWordsFormatter,
    HtmlDivFormatter,
    HtmlTableFormatter,
    LatexSongsFormatter,
    TextFormatter,
    UltimateGuitarFormatter
  }

  alias Sonx.Key

  alias Sonx.Parser.{
    ChordProParser,
    ChordsOverWordsParser,
    UltimateGuitarParser
  }

  alias Sonx.Serializer

  @type parser_format() :: :chord_pro | :chords_over_words | :ultimate_guitar
  @type formatter_format() ::
          :text
          | :chord_pro
          | :chords_over_words
          | :html_div
          | :html_table
          | :ultimate_guitar
          | :latex_songs

  # --- Parsing ---

  @doc """
  Parses a chord sheet string in the given format into a Song.

  ## Examples

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\\n[Am]Hello")
      iex> Sonx.title(song)
      "My Song"

      iex> {:ok, song} = Sonx.parse(:chords_over_words, "Am\\nHello")
      iex> Sonx.get_chords(song)
      ["Am"]

      iex> {:ok, song} = Sonx.parse(:ultimate_guitar, "[Verse]\\nAm\\nHello")
      iex> Sonx.get_chords(song)
      ["Am"]
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

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{title: Test}\\n[Am]Hello [G]world")
      iex> Sonx.format(:text, song)
      "Test\\n\\nAm    G\\nHello world"

      iex> {:ok, song} = Sonx.parse(:chord_pro, "[Am]Hello")
      iex> Sonx.format(:chord_pro, song)
      "[Am]Hello"
  """
  @spec format(formatter_format(), Song.t(), keyword()) :: String.t()
  def format(format, song, opts \\ [])

  def format(:text, song, opts), do: TextFormatter.format(song, opts)
  def format(:chord_pro, song, opts), do: ChordProFormatter.format(song, opts)
  def format(:chords_over_words, song, opts), do: ChordsOverWordsFormatter.format(song, opts)
  def format(:html_div, song, opts), do: HtmlDivFormatter.format(song, opts)
  def format(:html_table, song, opts), do: HtmlTableFormatter.format(song, opts)
  def format(:ultimate_guitar, song, opts), do: UltimateGuitarFormatter.format(song, opts)
  def format(:latex_songs, song, opts), do: LatexSongsFormatter.format(song, opts)

  # --- Chord Operations ---

  @doc """
  Transposes the song by the given number of semitones.

  ## Examples

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{key: C}\\n[C]Hello [G]world")
      iex> transposed = Sonx.transpose(song, 2)
      iex> Sonx.key(transposed)
      "D"
      iex> Sonx.get_chords(transposed)
      ["D", "A"]
  """
  @spec transpose(Song.t(), integer(), keyword()) :: Song.t()
  defdelegate transpose(song, delta, opts \\ []), to: Song

  @doc """
  Changes the song key to the target key, transposing all chords accordingly.

  Requires the song to have a key directive set.

  ## Examples

      iex> {:ok, song} = Sonx.parse(:chord_pro, "{key: C}\\n[C]Hello [Am]world")
      iex> changed = Sonx.change_key(song, "G")
      iex> Sonx.key(changed)
      "G"
      iex> Sonx.get_chords(changed)
      ["G", "Em"]
  """
  @spec change_key(Song.t(), String.t() | Key.t()) :: Song.t()
  defdelegate change_key(song, new_key), to: Song

  @doc """
  Switches all chords in the song to use the given accidental (`:sharp` or `:flat`).

  ## Examples

      iex> {:ok, song} = Sonx.parse(:chord_pro, "[C#]Hello")
      iex> flat = Sonx.use_accidental(song, :flat)
      iex> Sonx.get_chords(flat)
      ["Db"]
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

defmodule Sonx.ChordSheet.ChordLyricsPair do
  @moduledoc """
  Represents a chord with the corresponding (partial) lyrics.
  """

  use TypedStruct

  alias Sonx.Chord
  alias Sonx.Key

  typedstruct do
    field(:chords, String.t(), default: "")
    field(:lyrics, String.t() | nil, default: "")
    field(:annotation, String.t() | nil, default: "")
  end

  @spec new(String.t(), String.t() | nil, String.t() | nil) :: t()
  def new(chords \\ "", lyrics \\ "", annotation \\ "") do
    %__MODULE__{chords: chords || "", lyrics: lyrics || "", annotation: annotation || ""}
  end

  @doc "Returns the parsed Chord object, or nil if unparseable."
  @spec chord(t()) :: Chord.t() | nil
  def chord(%__MODULE__{chords: chords}) do
    Chord.parse(String.trim(chords))
  end

  @doc "Returns true if the pair has non-empty lyrics."
  @spec has_lyrics?(t()) :: boolean()
  def has_lyrics?(%__MODULE__{lyrics: nil}), do: false
  def has_lyrics?(%__MODULE__{lyrics: lyrics}), do: String.trim(lyrics) != ""

  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = pair) do
    %__MODULE__{chords: pair.chords, lyrics: pair.lyrics, annotation: pair.annotation}
  end

  @doc "Transposes the chord by delta semitones."
  @spec transpose(t(), integer(), Key.t() | nil, keyword()) :: t()
  def transpose(%__MODULE__{} = pair, delta, key \\ nil, opts \\ []) do
    normalize_suffix? = Keyword.get(opts, :normalize_chord_suffix, false)

    change_chord(pair, fn chord ->
      transposed = Chord.transpose(chord, delta)

      if key do
        Chord.normalize(transposed, key, normalize_suffix: normalize_suffix?)
      else
        transposed
      end
    end)
  end

  @doc "Switches to the specified accidental."
  @spec use_accidental(t(), Key.accidental()) :: t()
  def use_accidental(%__MODULE__{} = pair, accidental) do
    change_chord(pair, fn chord -> Chord.use_accidental(chord, accidental) end)
  end

  @doc "Applies a transformation function to the parsed chord."
  @spec change_chord(t(), (Chord.t() -> Chord.t())) :: t()
  def change_chord(%__MODULE__{chords: chords} = pair, func) do
    case Chord.parse(String.trim(chords)) do
      nil ->
        clone(pair)

      chord_obj ->
        changed = func.(chord_obj)
        %{pair | chords: Chord.to_string(changed)}
    end
  end

  @doc "Returns an updated pair with the given fields changed."
  @spec set(t(), keyword()) :: t()
  def set(%__MODULE__{} = pair, attrs) do
    %__MODULE__{
      chords: Keyword.get(attrs, :chords, pair.chords),
      lyrics: Keyword.get(attrs, :lyrics, pair.lyrics),
      annotation: Keyword.get(attrs, :annotation, pair.annotation)
    }
  end
end

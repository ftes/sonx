defmodule Sonx.Chord do
  @moduledoc """
  Represents a chord, consisting of a root key, optional bass key, and suffix.

  Supports parsing, transposition, normalization, accidental switching,
  and conversion between chord notation types (symbol, solfege, numeric, numeral).
  """

  use TypedStruct

  alias Sonx.Key
  alias Sonx.Parser.ChordParser

  typedstruct do
    field(:root, Key.t() | nil, default: nil)
    field(:bass, Key.t() | nil, default: nil)
    field(:suffix, String.t() | nil, default: nil)
    field(:optional, boolean(), default: false)
  end

  @doc """
  Parses a chord string into a Chord struct.
  Returns nil if the string cannot be parsed.
  """
  @spec parse(String.t()) :: t() | nil
  def parse(chord_string) do
    ChordParser.parse(chord_string)
  end

  @doc "Parses a chord string or raises on failure."
  @spec parse!(String.t()) :: t()
  def parse!(chord_string) do
    ChordParser.parse!(chord_string)
  end

  @doc "Returns a deep copy of the chord."
  @spec clone(t()) :: t()
  def clone(chord), do: %{chord | root: chord.root, bass: chord.bass}

  @doc "Transposes the chord by the specified number of semitones."
  @spec transpose(t(), integer()) :: t()
  def transpose(chord, delta) do
    transform(chord, fn key -> Key.transpose(key, delta) end)
  end

  @doc "Transposes the chord up by one semitone."
  @spec transpose_up(t()) :: t()
  def transpose_up(chord) do
    transform(chord, &Key.transpose_up/1)
  end

  @doc "Transposes the chord down by one semitone."
  @spec transpose_down(t()) :: t()
  def transpose_down(chord) do
    transform(chord, &Key.transpose_down/1)
  end

  @doc "Switches the chord to the specified accidental."
  @spec use_accidental(t(), Key.accidental()) :: t()
  def use_accidental(chord, accidental) do
    transform(chord, fn key -> Key.use_accidental(key, accidental) end)
  end

  @doc "Normalizes the chord root and bass notes."
  @spec normalize(t(), Key.t() | String.t() | nil, keyword()) :: t()
  def normalize(chord, _key \\ nil, opts \\ []) do
    _normalize_suffix = Keyword.get(opts, :normalize_suffix, true)

    root = if chord.root, do: Key.normalize(chord.root)
    bass = if chord.bass, do: Key.normalize(chord.bass)

    %{chord | root: root, bass: bass}
  end

  @doc "Determines whether the chord is a chord symbol."
  @spec chord_symbol?(t()) :: boolean()
  def chord_symbol?(chord), do: type?(chord, :symbol)

  @doc "Determines whether the chord is a chord solfege."
  @spec chord_solfege?(t()) :: boolean()
  def chord_solfege?(chord), do: type?(chord, :solfege)

  @doc "Determines whether the chord is numeric."
  @spec numeric?(t()) :: boolean()
  def numeric?(chord), do: type?(chord, :numeric)

  @doc "Determines whether the chord is a numeral."
  @spec numeral?(t()) :: boolean()
  def numeral?(chord), do: type?(chord, :numeral)

  @doc "Converts the chord to a chord symbol notation."
  @spec to_chord_symbol(t(), Key.t() | String.t() | nil) :: t()
  def to_chord_symbol(%__MODULE__{} = chord, _ref) when chord.root == nil, do: chord

  def to_chord_symbol(chord, reference_key) do
    if chord_symbol?(chord) do
      clone(chord)
    else
      ref = prepare_reference_key(reference_key)

      %{
        chord
        | root: Key.to_chord_symbol(chord.root, ref),
          bass: if(chord.bass, do: Key.to_chord_symbol(chord.bass, ref))
      }
      |> normalize(reference_key)
    end
  end

  @doc "Converts the chord to solfege notation."
  @spec to_chord_solfege(t(), Key.t() | String.t() | nil) :: t()
  def to_chord_solfege(chord, reference_key) do
    if chord_solfege?(chord) do
      clone(chord)
    else
      ref = prepare_reference_key(reference_key)

      %{
        chord
        | root: if(chord.root, do: Key.to_chord_solfege(chord.root, ref)),
          bass: if(chord.bass, do: Key.to_chord_solfege(chord.bass, ref))
      }
      |> normalize(reference_key)
    end
  end

  @doc "Converts the chord to numeric notation."
  @spec to_numeric(t(), Key.t() | String.t() | nil) :: t()
  def to_numeric(chord, reference_key) do
    cond do
      numeric?(chord) ->
        clone(chord)

      numeral?(chord) ->
        transform(chord, fn key -> Key.to_numeric(key, nil) end)

      true ->
        ref = prepare_reference_key(reference_key)

        %{
          chord
          | root: if(chord.root, do: Key.to_numeric(chord.root, ref)),
            bass: if(chord.bass, do: Key.to_numeric(chord.bass, ref))
        }
    end
  end

  @doc "Converts the chord to numeral notation."
  @spec to_numeral(t(), Key.t() | String.t() | nil) :: t()
  def to_numeral(chord, reference_key) do
    cond do
      numeral?(chord) ->
        clone(chord)

      numeric?(chord) ->
        transform(chord, fn key -> Key.to_numeral(key, nil) end)

      true ->
        ref = prepare_reference_key(reference_key)

        %{
          chord
          | root: if(chord.root, do: Key.to_numeral(chord.root, ref)),
            bass: if(chord.bass, do: Key.to_numeral(chord.bass, ref))
        }
    end
  end

  @doc "Returns whether the chord's root is minor."
  @spec minor?(t()) :: boolean()
  def minor?(%__MODULE__{root: nil}), do: false
  def minor?(%__MODULE__{root: root}), do: Key.minor?(root)

  @doc "Converts the chord to its string representation."
  @spec to_string(t(), keyword()) :: String.t()
  def to_string(chord, opts \\ []) do
    unicode_accidentals? = Keyword.get(opts, :unicode_accidentals, false)

    chord_string =
      if chord.root do
        suffix = chord.suffix || ""
        show_minor? = not String.starts_with?(suffix, "m")
        root_str = Key.to_string(chord.root, show_minor: show_minor?, unicode_accidentals: unicode_accidentals?)
        root_str <> suffix
      else
        ""
      end

    chord_string =
      if chord.bass do
        bass_str = Key.to_string(chord.bass, unicode_accidentals: unicode_accidentals?)
        chord_string <> "/" <> bass_str
      else
        chord_string
      end

    if chord.optional do
      "(#{chord_string})"
    else
      chord_string
    end
  end

  @doc "Returns true if two chords are structurally equal."
  @spec equals?(t(), t()) :: boolean()
  def equals?(a, b) do
    a.suffix == b.suffix and
      a.optional == b.optional and
      Key.equals?(a.root, b.root) and
      Key.equals?(a.bass, b.bass)
  end

  # --- Private ---

  defp type?(chord, type) do
    root_ok = chord.root == nil or Key.type?(chord.root, type)
    bass_ok = chord.bass == nil or Key.type?(chord.bass, type)
    root_ok and bass_ok
  end

  defp transform(chord, func) do
    %{
      chord
      | root: if(chord.root, do: func.(chord.root)),
        bass: if(chord.bass, do: func.(chord.bass))
    }
  end

  defp prepare_reference_key(nil), do: nil

  defp prepare_reference_key(ref) do
    key = Key.wrap!(ref)
    if Key.minor?(key), do: Key.relative_major(key), else: key
  end

  defimpl String.Chars do
    def to_string(chord) do
      Sonx.Chord.to_string(chord)
    end
  end
end

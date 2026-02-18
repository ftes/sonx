defmodule Sonx.ChordDiagrams do
  @moduledoc """
  Guitar chord diagram lookup.

  Maps chord names to fret position strings for common guitar chords.
  Strings are ordered low E → high E. `X` = muted, `0` = open.

  ## Examples

      iex> Sonx.ChordDiagrams.lookup_frets("Am")
      "X02210"

      iex> Sonx.ChordDiagrams.lookup_frets("C/G")
      "332010"

      iex> Sonx.ChordDiagrams.lookup_frets("Cmaj9")
      nil
  """

  # Guitar fret positions for common chords, keyed by {semitone_grade, suffix}.
  # Strings are ordered low E → high E. X = muted, 0 = open.
  @frets %{
    # Major
    {0, nil} => "X32010",
    {1, nil} => "X46664",
    {2, nil} => "XX0232",
    {3, nil} => "XX1343",
    {4, nil} => "022100",
    {5, nil} => "133211",
    {6, nil} => "244322",
    {7, nil} => "320003",
    {8, nil} => "466544",
    {9, nil} => "X02220",
    {10, nil} => "X13331",
    {11, nil} => "X24442",
    # Minor
    {0, "m"} => "X35543",
    {1, "m"} => "X46654",
    {2, "m"} => "XX0231",
    {3, "m"} => "XX1342",
    {4, "m"} => "022000",
    {5, "m"} => "133111",
    {6, "m"} => "244222",
    {7, "m"} => "355333",
    {8, "m"} => "466444",
    {9, "m"} => "X02210",
    {10, "m"} => "X13321",
    {11, "m"} => "X24432",
    # Dominant 7th
    {0, "7"} => "X32310",
    {1, "7"} => "X46464",
    {2, "7"} => "XX0212",
    {4, "7"} => "020100",
    {5, "7"} => "131211",
    {6, "7"} => "242322",
    {7, "7"} => "320001",
    {8, "7"} => "464544",
    {9, "7"} => "X02020",
    {10, "7"} => "X13131",
    {11, "7"} => "X21202",
    # Minor 7th
    {0, "m7"} => "X35343",
    {2, "m7"} => "XX0211",
    {4, "m7"} => "022030",
    {5, "m7"} => "131111",
    {6, "m7"} => "242222",
    {7, "m7"} => "353333",
    {9, "m7"} => "X02010",
    {11, "m7"} => "X24232",
    # Major 7th
    {0, "maj7"} => "X32000",
    {2, "maj7"} => "XX0222",
    {4, "maj7"} => "021100",
    {5, "maj7"} => "X33210",
    {7, "maj7"} => "320002",
    {9, "maj7"} => "X02120",
    # Sus2
    {2, "sus2"} => "XX0230",
    {4, "sus2"} => "024400",
    {9, "sus2"} => "X02200",
    # Sus4
    {2, "sus4"} => "XX0233",
    {4, "sus4"} => "022200",
    {9, "sus4"} => "X02230"
  }

  # Common slash chord voicings: {root_grade, suffix, bass_grade}
  @slash_frets %{
    {0, nil, 7} => "332010",
    {0, nil, 4} => "032010",
    {2, nil, 6} => "200232",
    {7, nil, 11} => "X20003"
  }

  @doc """
  Looks up fret positions for a chord name string.
  Returns the fret position string (e.g. `"X02210"`) or `nil` if unknown.
  """
  @spec lookup_frets(String.t()) :: String.t() | nil
  def lookup_frets(chord_name) do
    case Sonx.Chord.parse(chord_name) do
      nil -> nil
      %{bass: bass} = chord when not is_nil(bass) -> lookup_slash(chord) || lookup_base(chord)
      chord -> lookup_base(chord)
    end
  end

  defp lookup_slash(%{root: root, suffix: suffix, bass: bass}) do
    Map.get(@slash_frets, {root.reference_key_grade, suffix, bass.reference_key_grade})
  end

  defp lookup_base(%{root: root, suffix: suffix}) do
    Map.get(@frets, {root.reference_key_grade, suffix})
  end
end

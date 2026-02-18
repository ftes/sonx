defmodule Sonx.ChordDiagramsTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordDiagrams

  describe "lookup_frets/1" do
    test "finds common open chords" do
      assert ChordDiagrams.lookup_frets("Am") == "X02210"
      assert ChordDiagrams.lookup_frets("C") == "X32010"
      assert ChordDiagrams.lookup_frets("G") == "320003"
    end

    test "handles enharmonic equivalents" do
      # Bb and A# both map to grade 10
      assert ChordDiagrams.lookup_frets("Bb") == "X13331"
      assert ChordDiagrams.lookup_frets("A#") == "X13331"
    end

    test "finds slash chords with known voicings" do
      assert ChordDiagrams.lookup_frets("C/G") == "332010"
      assert ChordDiagrams.lookup_frets("C/E") == "032010"
    end

    test "falls back to base chord for unknown slash voicing" do
      # Am/G has no specific slash entry, falls back to Am
      assert ChordDiagrams.lookup_frets("Am/G") == "X02210"
    end

    test "returns nil for unknown chords" do
      assert ChordDiagrams.lookup_frets("Cmaj9") == nil
      assert ChordDiagrams.lookup_frets("not_a_chord") == nil
    end
  end
end

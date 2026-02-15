defmodule Sonx.ChordTest do
  use ExUnit.Case, async: true

  alias Sonx.Chord
  alias Sonx.Key

  describe "parse/1" do
    test "parses simple chord" do
      chord = Chord.parse("Am")
      assert chord != nil
      assert chord.root != nil
      assert Key.minor?(chord.root)
    end

    test "parses chord with suffix" do
      chord = Chord.parse("Am7")
      assert chord != nil
      assert chord.suffix =~ "7"
    end

    test "parses chord with bass note" do
      chord = Chord.parse("C/G")
      assert chord != nil
      assert chord.root != nil
      assert chord.bass != nil
    end

    test "parses chord with sharp" do
      chord = Chord.parse("F#m")
      assert chord != nil
      assert chord.root.accidental == :sharp
    end

    test "parses chord with flat" do
      chord = Chord.parse("Bb")
      assert chord != nil
      assert chord.root.accidental == :flat
    end

    test "returns nil for empty string" do
      assert Chord.parse("") == nil
    end

    test "returns nil for unparseable string" do
      assert Chord.parse("not a chord!!!") == nil
    end
  end

  describe "to_string/1" do
    test "renders simple chord" do
      chord = Chord.parse!("C")
      assert Chord.to_string(chord) == "C"
    end

    test "renders chord with suffix" do
      chord = Chord.parse!("Am7")
      assert Chord.to_string(chord) == "Am7"
    end

    test "renders chord with bass" do
      chord = Chord.parse!("C/G")
      assert Chord.to_string(chord) == "C/G"
    end
  end

  describe "transpose/2" do
    test "transposes chord up" do
      chord = Chord.parse!("C")
      transposed = Chord.transpose(chord, 2)
      assert Chord.to_string(transposed) == "D"
    end

    test "transposes chord with bass" do
      chord = Chord.parse!("C/G")
      transposed = Chord.transpose(chord, 2)
      result = Chord.to_string(transposed)
      assert result == "D/A"
    end
  end

  describe "type queries" do
    test "chord_symbol?" do
      chord = Chord.parse!("Am")
      assert Chord.chord_symbol?(chord)
    end

    test "minor?" do
      assert Chord.minor?(Chord.parse!("Am"))
      refute Chord.minor?(Chord.parse!("C"))
    end
  end

  describe "equals?/2" do
    test "equal chords" do
      a = Chord.parse!("Am7")
      b = Chord.parse!("Am7")
      assert Chord.equals?(a, b)
    end

    test "different chords" do
      a = Chord.parse!("Am")
      b = Chord.parse!("C")
      refute Chord.equals?(a, b)
    end
  end
end

defmodule Sonx.Parser.ChordParserTest do
  use ExUnit.Case, async: true

  alias Sonx.{Chord, Key}
  alias Sonx.Parser.ChordParser

  describe "symbol chords" do
    test "parses simple major chord" do
      chord = ChordParser.parse!("C")
      assert chord.root.type == :symbol
      assert Key.to_string(chord.root) == "C"
      assert chord.suffix == nil
    end

    test "parses minor chord" do
      chord = ChordParser.parse!("Am")
      assert Key.minor?(chord.root)
      assert chord.suffix == "m"
    end

    test "parses chord with sharp" do
      chord = ChordParser.parse!("F#")
      assert chord.root.accidental == :sharp
    end

    test "parses chord with flat" do
      chord = ChordParser.parse!("Bb")
      assert chord.root.accidental == :flat
    end

    test "parses chord with suffix" do
      chord = ChordParser.parse!("Am7")
      assert chord.suffix == "m7"
    end

    test "parses sus4" do
      chord = ChordParser.parse!("Csus4")
      assert chord.suffix == "sus4"
    end

    test "parses sus2" do
      chord = ChordParser.parse!("Dsus2")
      assert chord.suffix == "sus2"
    end

    test "parses dim" do
      chord = ChordParser.parse!("Bdim")
      assert chord.suffix == "dim"
    end

    test "parses aug" do
      chord = ChordParser.parse!("Caug")
      assert chord.suffix == "aug"
    end

    test "parses chord with bass note" do
      chord = ChordParser.parse!("C/G")
      assert chord.root != nil
      assert chord.bass != nil
      assert Key.to_string(chord.bass, show_minor: false) == "G"
    end

    test "parses complex chord: Ebsus4/Bb" do
      chord = ChordParser.parse!("Ebsus4/Bb")
      assert chord.root.accidental == :flat
      assert chord.suffix == "sus4"
      assert chord.bass != nil
      assert chord.bass.accidental == :flat
    end

    test "parses major 7" do
      chord = ChordParser.parse!("Cmaj7")
      assert chord.suffix =~ "maj7"
    end

    test "parses add9" do
      chord = ChordParser.parse!("Cadd9")
      assert chord.suffix =~ "add9"
    end

    test "parses m7b5" do
      chord = ChordParser.parse!("Cm7b5")
      assert chord.suffix =~ "m7b5"
    end
  end

  describe "solfege chords" do
    test "parses Do" do
      chord = ChordParser.parse!("Do")
      assert chord.root.type == :solfege
    end

    test "parses Sol#m" do
      chord = ChordParser.parse!("Sol#m")
      assert chord.root.type == :solfege
      assert chord.root.accidental == :sharp
      assert Key.minor?(chord.root)
    end

    test "parses Fa (not Fadd)" do
      chord = ChordParser.parse!("Fa")
      assert chord.root.type == :solfege
      assert Key.to_string(chord.root, show_minor: false) == "Fa"
    end

    test "parses Reb/Sol" do
      chord = ChordParser.parse!("Reb/Sol")
      assert chord.root.type == :solfege
      assert chord.root.accidental == :flat
      assert chord.bass != nil
    end
  end

  describe "numeric chords" do
    test "parses 1" do
      chord = ChordParser.parse!("1")
      assert chord.root.type == :numeric
      assert chord.root.number == 1
    end

    test "parses #4" do
      chord = ChordParser.parse!("#4")
      assert chord.root.type == :numeric
      assert chord.root.accidental == :sharp
      assert chord.root.number == 4
    end

    test "parses b3" do
      chord = ChordParser.parse!("b3")
      assert chord.root.type == :numeric
      assert chord.root.accidental == :flat
      assert chord.root.number == 3
    end

    test "parses 5/1" do
      chord = ChordParser.parse!("5/1")
      assert chord.root.number == 5
      assert chord.bass != nil
    end

    test "parses #4/b3" do
      chord = ChordParser.parse!("#4/b3")
      assert chord.root.accidental == :sharp
      assert chord.bass.accidental == :flat
    end
  end

  describe "numeral chords" do
    test "parses IV" do
      chord = ChordParser.parse!("IV")
      assert chord.root.type == :numeral
      assert chord.root.number == 4
    end

    test "parses vi (minor)" do
      chord = ChordParser.parse!("vi")
      assert chord.root.type == :numeral
      assert chord.root.minor == true
    end

    test "parses #IV" do
      chord = ChordParser.parse!("#IV")
      assert chord.root.accidental == :sharp
    end

    test "parses bVII" do
      chord = ChordParser.parse!("bVII")
      assert chord.root.accidental == :flat
      assert chord.root.number == 7
    end

    test "parses V/I" do
      chord = ChordParser.parse!("V/I")
      assert chord.root.number == 5
      assert chord.bass != nil
    end
  end

  describe "optional chords" do
    test "parses optional chord" do
      chord = ChordParser.parse!("(Am)")
      assert chord.optional == true
      assert Key.minor?(chord.root)
    end

    test "parses optional chord with bass" do
      chord = ChordParser.parse!("(C/G)")
      assert chord.optional == true
      assert chord.bass != nil
    end
  end

  describe "round-trip" do
    for chord_str <- ~w(C Am F#m Bb Csus4 Dsus2 Bdim Caug) do
      test "round-trips #{chord_str}" do
        chord = ChordParser.parse!(unquote(chord_str))
        assert Chord.to_string(chord) == unquote(chord_str)
      end
    end
  end

  describe "edge cases" do
    test "returns nil for empty string" do
      assert ChordParser.parse("") == nil
    end

    test "returns nil for whitespace" do
      assert ChordParser.parse("  ") == nil
    end

    test "returns nil for garbage" do
      assert ChordParser.parse("not_a_chord!!!") == nil
    end
  end
end

defmodule Sonx.KeyTest do
  use ExUnit.Case, async: true

  alias Sonx.Key

  describe "parse/1" do
    test "parses symbol keys" do
      key = Key.parse("C")
      assert key != nil
      assert key.type == :symbol
      assert key.minor == false
    end

    test "parses symbol key with sharp" do
      key = Key.parse("C#")
      assert key.type == :symbol
      assert key.accidental == :sharp
    end

    test "parses symbol key with flat" do
      key = Key.parse("Eb")
      assert key.type == :symbol
      assert key.accidental == :flat
    end

    test "parses minor symbol key" do
      key = Key.parse("Am")
      assert key.type == :symbol
      assert key.minor == true
    end

    test "parses solfege keys" do
      key = Key.parse("Do")
      assert key != nil
      assert key.type == :solfege
    end

    test "parses solfege key with sharp" do
      key = Key.parse("Fa#")
      assert key.type == :solfege
      assert key.accidental == :sharp
    end

    test "parses minor solfege key" do
      key = Key.parse("Lam")
      assert key.type == :solfege
      assert key.minor == true
    end

    test "parses numeric keys" do
      key = Key.parse("1")
      assert key != nil
      assert key.type == :numeric
      assert key.number == 1
    end

    test "parses numeric key with sharp" do
      key = Key.parse("#4")
      assert key.type == :numeric
      assert key.accidental == :sharp
      assert key.number == 4
    end

    test "parses numeric key with flat" do
      key = Key.parse("b3")
      assert key.type == :numeric
      assert key.accidental == :flat
      assert key.number == 3
    end

    test "parses numeral keys" do
      key = Key.parse("IV")
      assert key != nil
      assert key.type == :numeral
      assert key.number == 4
      assert key.minor == false
    end

    test "parses minor numeral keys (lowercase)" do
      key = Key.parse("vi")
      assert key.type == :numeral
      assert key.number == 6
      assert key.minor == true
    end

    test "returns nil for empty string" do
      assert Key.parse("") == nil
      assert Key.parse(nil) == nil
    end

    test "returns nil for unparseable string" do
      assert Key.parse("xyz") == nil
    end
  end

  describe "to_string/1" do
    test "renders symbol key" do
      key = Key.parse("C")
      assert Key.to_string(key) == "C"
    end

    test "renders symbol key with sharp" do
      key = Key.parse("F#")
      assert Key.to_string(key) == "F#"
    end

    test "renders symbol key with flat" do
      key = Key.parse("Bb")
      assert Key.to_string(key) == "Bb"
    end

    test "renders minor symbol key" do
      key = Key.parse("Am")
      assert Key.to_string(key) == "Am"
    end

    test "renders solfege key" do
      key = Key.parse("Sol")
      assert Key.to_string(key) == "Sol"
    end

    test "renders numeric key" do
      key = Key.parse("5")
      assert Key.to_string(key) == "5"
    end

    test "renders numeric key with sharp" do
      key = Key.parse("#4")
      assert Key.to_string(key) == "#4"
    end

    test "renders numeral key" do
      key = Key.parse("IV")
      assert Key.to_string(key) == "IV"
    end

    test "renders minor numeral key" do
      key = Key.parse("vi")
      assert Key.to_string(key) == "vi"
    end

    test "renders with unicode modifiers" do
      key = Key.parse("F#")
      assert Key.to_string(key, unicode_accidentals: true) == "F\u266F"
    end
  end

  describe "transpose/2" do
    test "transposes C up by 2 semitones" do
      key = Key.parse!("C")
      transposed = Key.transpose(key, 2)
      assert Key.to_string(transposed) == "D"
    end

    test "transposes C up by 1 semitone" do
      key = Key.parse!("C")
      transposed = Key.transpose(key, 1)
      assert Key.to_string(transposed) == "C#"
    end

    test "transposes by 0 returns same key" do
      key = Key.parse!("E")
      assert Key.transpose(key, 0) == key
    end
  end

  describe "distance/2" do
    test "distance from C to D is 2" do
      assert Key.distance("C", "D") == 2
    end

    test "distance from C to G is 7" do
      assert Key.distance("C", "G") == 7
    end
  end

  describe "wrap/1" do
    test "wraps a string" do
      assert %Key{} = Key.wrap("Am")
    end

    test "passes through a Key struct" do
      key = Key.parse!("C")
      assert Key.wrap(key) == key
    end

    test "returns nil for nil" do
      assert Key.wrap(nil) == nil
    end
  end

  describe "equals?/2" do
    test "equal keys" do
      a = Key.parse("C")
      b = Key.parse("C")
      assert Key.equals?(a, b)
    end

    test "different keys" do
      a = Key.parse("C")
      b = Key.parse("D")
      refute Key.equals?(a, b)
    end

    test "nil handling" do
      assert Key.equals?(nil, nil)
      refute Key.equals?(Key.parse("C"), nil)
      refute Key.equals?(nil, Key.parse("C"))
    end
  end

  describe "transpose enharmonic normalization" do
    test "transpose by 12 returns natural note names" do
      for {note, expected} <- [{"C", "C"}, {"D", "D"}, {"E", "E"}, {"F", "F"}, {"G", "G"}, {"A", "A"}, {"B", "B"}] do
        key = Key.parse!(note)
        transposed = Key.transpose(key, 12)

        assert Key.to_string(transposed) == expected,
               "#{note} transposed by 12 should be #{expected}, got #{Key.to_string(transposed)}"
      end
    end

    test "transpose by -12 returns natural note names" do
      for {note, expected} <- [{"C", "C"}, {"D", "D"}, {"E", "E"}, {"F", "F"}, {"G", "G"}, {"A", "A"}, {"B", "B"}] do
        key = Key.parse!(note)
        transposed = Key.transpose(key, -12)

        assert Key.to_string(transposed) == expected,
               "#{note} transposed by -12 should be #{expected}, got #{Key.to_string(transposed)}"
      end
    end

    test "transpose avoids B# for C" do
      key = Key.parse!("C")
      transposed = Key.transpose(key, 12)
      refute Key.to_string(transposed) == "B#"
    end

    test "transpose avoids E# for F" do
      key = Key.parse!("F")
      transposed = Key.transpose(key, 12)
      refute Key.to_string(transposed) == "E#"
    end

    test "transpose avoids Cb for B" do
      key = Key.parse!("B")
      transposed = Key.transpose(key, -12)
      refute Key.to_string(transposed) == "Cb"
    end

    test "transpose avoids Fb for E" do
      key = Key.parse!("E")
      transposed = Key.transpose(key, -12)
      refute Key.to_string(transposed) == "Fb"
    end

    test "sharp keys remain sharp after transpose by 12" do
      for {note, expected} <- [{"C#", "C#"}, {"F#", "F#"}, {"G#", "G#"}] do
        key = Key.parse!(note)
        transposed = Key.transpose(key, 12)

        assert Key.to_string(transposed) == expected,
               "#{note} transposed by 12 should be #{expected}, got #{Key.to_string(transposed)}"
      end
    end

    test "flat keys remain flat after transpose by 12" do
      for {note, expected} <- [{"Db", "Db"}, {"Eb", "Eb"}, {"Bb", "Bb"}] do
        key = Key.parse!(note)
        transposed = Key.transpose(key, 12)

        assert Key.to_string(transposed) == expected,
               "#{note} transposed by 12 should be #{expected}, got #{Key.to_string(transposed)}"
      end
    end
  end

  describe "use_accidental/2" do
    test "switches C# to Db" do
      key = Key.parse!("C#")
      flatted = Key.use_accidental(key, :flat)
      assert Key.to_string(flatted) == "Db"
    end

    test "switches Db to C#" do
      key = Key.parse!("Db")
      sharped = Key.use_accidental(key, :sharp)
      assert Key.to_string(sharped) == "C#"
    end

    test "switches Bb to A#" do
      key = Key.parse!("Bb")
      sharped = Key.use_accidental(key, :sharp)
      assert Key.to_string(sharped) == "A#"
    end

    test "natural notes get enharmonic with sharp" do
      # C with sharp accidental becomes B# (enharmonic equivalent)
      key = Key.parse!("C")
      sharped = Key.use_accidental(key, :sharp)
      assert Key.to_string(sharped) == "B#"
    end

    test "natural notes get enharmonic with flat" do
      # B with flat accidental becomes Cb (enharmonic equivalent)
      key = Key.parse!("B")
      flatted = Key.use_accidental(key, :flat)
      assert Key.to_string(flatted) == "Cb"
    end

    test "E with sharp becomes E# (enharmonic of F)" do
      key = Key.parse!("F")
      sharped = Key.use_accidental(key, :sharp)
      assert Key.to_string(sharped) == "E#"
    end
  end
end

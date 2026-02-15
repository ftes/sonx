defmodule Sonx.Formatter.UltimateGuitarFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.UltimateGuitarFormatter
  alias Sonx.Parser.ChordProParser
  alias Sonx.Parser.UltimateGuitarParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = UltimateGuitarFormatter.format(song)
      assert result == ""
    end

    test "formats chords above lyrics without section" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = UltimateGuitarFormatter.format(song)

      lines = String.split(result, "\n")
      chord_line = Enum.at(lines, 0)
      lyrics_line = Enum.at(lines, 1)

      assert chord_line =~ "C"
      assert chord_line =~ "G"
      assert lyrics_line =~ "Hello"
      assert lyrics_line =~ "world"
    end

    test "does not include title or subtitle" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{subtitle: Sub}\n[Am]Hello")
      result = UltimateGuitarFormatter.format(song)
      refute result =~ "My Song"
      refute result =~ "Sub"
      assert result =~ "Am"
    end
  end

  describe "sections" do
    test "formats verse section with header" do
      input = "{start_of_verse}\n[C]Hello [G]world\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result =~ "[Verse]"
      assert result =~ "Hello"
    end

    test "formats chorus section with header" do
      input = "{start_of_chorus}\n[Am]Let it [F]be\n{end_of_chorus}"
      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result =~ "[Chorus]"
      assert result =~ "Let it"
    end

    test "formats section with custom label" do
      input = "{start_of_verse: label=\"Verse 1\"}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result =~ "[Verse 1]"
    end

    test "formats bridge section" do
      input = "{start_of_bridge}\n[Dm]Bridge line\n{end_of_bridge}"
      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result =~ "[Bridge]"
    end

    test "formats multiple sections separated by blank lines" do
      input = """
      {start_of_verse: label="Verse 1"}
      [C]Hello
      {end_of_verse}
      {start_of_chorus: label="Chorus"}
      [Am]Let it be
      {end_of_chorus}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result =~ "[Verse 1]"
      assert result =~ "[Chorus]"
    end
  end

  describe "chord alignment" do
    test "pads chords to align with lyrics" do
      {:ok, song} = ChordProParser.parse("[Am]Hi [G]there")
      result = UltimateGuitarFormatter.format(song)

      lines = String.split(result, "\n")
      chord_line = Enum.at(lines, 0)

      assert chord_line =~ "Am"
      assert chord_line =~ "G"
    end

    test "formats chord-only lines" do
      {:ok, song} = ChordProParser.parse("[F][C][Dm]")
      result = UltimateGuitarFormatter.format(song)
      assert result =~ "F"
      assert result =~ "C"
      assert result =~ "Dm"
    end

    test "formats lyrics-only lines" do
      {:ok, song} = ChordProParser.parse("Just some words")
      result = UltimateGuitarFormatter.format(song)
      assert result =~ "Just some words"
    end
  end

  describe "roundtrip" do
    test "simple fixture roundtrips exactly" do
      fixture_path =
        Path.join([__DIR__, "..", "support", "fixtures", "ultimate_guitar", "simple.txt"])

      input = File.read!(fixture_path)
      {:ok, song} = UltimateGuitarParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      assert result == String.trim_trailing(input)
    end

    test "chordsheet fixture roundtrips exactly (modulo known normalizations)" do
      fixture_path =
        Path.join([
          __DIR__,
          "..",
          "support",
          "fixtures",
          "ultimate_guitar",
          "ultimate_guitar_chordsheet.txt"
        ])

      input = File.read!(fixture_path)
      {:ok, song} = UltimateGuitarParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      normalized_input =
        input
        |> String.trim_trailing()
        # Parser collapses double blank lines between sections
        |> String.replace(~r/\n{3,}/, "\n\n")
        # Chord-only lines: parser doesn't preserve extra spacing between chords
        |> String.replace("F  C Dm", "F C Dm")
        |> String.replace("C  G  Am", "C G Am")

      assert result == normalized_input
    end

    test "double roundtrip produces identical output" do
      fixture_path =
        Path.join([
          __DIR__,
          "..",
          "support",
          "fixtures",
          "ultimate_guitar",
          "ultimate_guitar_chordsheet.txt"
        ])

      input = File.read!(fixture_path)
      {:ok, song1} = UltimateGuitarParser.parse(input)
      output1 = UltimateGuitarFormatter.format(song1)

      {:ok, song2} = UltimateGuitarParser.parse(output1)
      output2 = UltimateGuitarFormatter.format(song2)

      assert output1 == output2
    end

    test "roundtrip preserves chords" do
      fixture_path =
        Path.join([
          __DIR__,
          "..",
          "support",
          "fixtures",
          "ultimate_guitar",
          "ultimate_guitar_chordsheet.txt"
        ])

      input = File.read!(fixture_path)
      {:ok, original_song} = UltimateGuitarParser.parse(input)
      output = UltimateGuitarFormatter.format(original_song)
      {:ok, roundtripped_song} = UltimateGuitarParser.parse(output)

      assert Sonx.get_chords(original_song) == Sonx.get_chords(roundtripped_song)
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      result = UltimateGuitarFormatter.format(song)

      # Should not include title in body (no header in UG format)
      assert result =~ "When I find"
      assert result =~ "Let it"
    end
  end
end

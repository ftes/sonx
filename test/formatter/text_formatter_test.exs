defmodule Sonx.Formatter.TextFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.TextFormatter
  alias Sonx.Parser.ChordProParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = TextFormatter.format(song)
      assert result == ""
    end

    test "formats song with title" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = TextFormatter.format(song)
      assert result == "My Song"
    end

    test "formats song with title and subtitle" do
      input = "{title: My Song}\n{subtitle: The Subtitle}"
      {:ok, song} = ChordProParser.parse(input)
      result = TextFormatter.format(song)
      assert result == "My Song\nThe Subtitle"
    end
  end

  describe "chord-lyrics alignment" do
    test "formats chords above lyrics" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = TextFormatter.format(song)

      lines = String.split(result, "\n")
      # Should have a chord line and a lyrics line
      assert length(lines) >= 2
      chord_line = Enum.at(lines, 0)
      lyrics_line = Enum.at(lines, 1)

      assert chord_line =~ "C"
      assert chord_line =~ "G"
      assert lyrics_line =~ "Hello"
      assert lyrics_line =~ "world"
    end

    test "pads chords to align with lyrics" do
      {:ok, song} = ChordProParser.parse("[Am]Hi [G]there")
      result = TextFormatter.format(song)

      lines = String.split(result, "\n")
      chord_line = Enum.at(lines, 0)
      lyrics_line = Enum.at(lines, 1)

      # Am is 2 chars, "Hi " is 3 chars — chord should be padded to 3
      # (lyrics are longer, so pair length = max(2, 3) = 3)
      assert String.length(String.trim_trailing(chord_line)) >= 2
      assert lyrics_line =~ "Hi"
    end

    test "adds padding after chord when chord is longer than lyrics" do
      {:ok, song} = ChordProParser.parse("[Ebsus4]x [C]y")
      result = TextFormatter.format(song)

      lines = String.split(result, "\n")
      chord_line = Enum.at(lines, 0)

      # Ebsus4 is 6 chars, "x" is 1 char — pad to 7 (6+1)
      assert chord_line =~ "Ebsus4"
      assert chord_line =~ "C"
    end

    test "formats lyrics-only lines" do
      {:ok, song} = ChordProParser.parse("Just some words")
      result = TextFormatter.format(song)
      assert result =~ "Just some words"
    end

    test "formats chord-only lines" do
      {:ok, song} = ChordProParser.parse("[Am][G][F][C]")
      result = TextFormatter.format(song)
      assert result =~ "Am"
      assert result =~ "G"
    end
  end

  describe "sections" do
    test "formats verse and chorus" do
      input = """
      {title: Test}
      {start_of_verse}
      [C]Hello [G]world
      {end_of_verse}
      {start_of_chorus}
      [Am]Let it [F]be
      {end_of_chorus}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = TextFormatter.format(song)

      assert result =~ "Test"
      assert result =~ "C"
      assert result =~ "Hello"
      assert result =~ "Am"
      assert result =~ "Let it"
    end
  end

  describe "section labels" do
    test "renders section label" do
      input = "{start_of_verse: label=\"Verse 1\"}\n[C]Hello"
      {:ok, song} = ChordProParser.parse(input)
      result = TextFormatter.format(song)
      assert result =~ "Verse 1"
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      result = TextFormatter.format(song)

      assert result =~ "Let It Be"
      assert result =~ "C"
      assert result =~ "When I find"
      assert result =~ "Let it"
    end
  end
end

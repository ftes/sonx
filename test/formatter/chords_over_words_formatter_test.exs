defmodule Sonx.Formatter.ChordsOverWordsFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.ChordsOverWordsFormatter
  alias Sonx.Parser.ChordProParser
  alias Sonx.Parser.ChordsOverWordsParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = ChordsOverWordsFormatter.format(song)
      assert result == ""
    end

    test "formats metadata header" do
      input = "{title: My Song}\n{artist: John Doe}\n{key: C}"
      {:ok, song} = ChordProParser.parse(input)
      result = ChordsOverWordsFormatter.format(song)

      assert result =~ "title: My Song"
      assert result =~ "artist: John Doe"
      assert result =~ "key: C"
    end
  end

  describe "chord-lyrics alignment" do
    test "formats chords above lyrics" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = ChordsOverWordsFormatter.format(song)

      lines = String.split(result, "\n")
      chord_line = Enum.at(lines, 0)
      lyrics_line = Enum.at(lines, 1)

      assert chord_line =~ "C"
      assert chord_line =~ "G"
      assert lyrics_line =~ "Hello"
      assert lyrics_line =~ "world"
    end

    test "formats lyrics without chords" do
      {:ok, song} = ChordProParser.parse("Just some lyrics")
      result = ChordsOverWordsFormatter.format(song)
      assert result =~ "Just some lyrics"
    end
  end

  describe "metadata ordering" do
    test "orders metadata by standard order" do
      input = "{key: C}\n{artist: John}\n{title: Song}"
      {:ok, song} = ChordProParser.parse(input)
      result = ChordsOverWordsFormatter.format(song)

      lines = String.split(result, "\n")
      meta_lines = Enum.filter(lines, &String.contains?(&1, ": "))

      # title should come before artist, which should come before key
      title_idx = Enum.find_index(meta_lines, &String.contains?(&1, "title"))
      artist_idx = Enum.find_index(meta_lines, &String.contains?(&1, "artist"))
      key_idx = Enum.find_index(meta_lines, &String.contains?(&1, "key"))

      assert title_idx < artist_idx
      assert artist_idx < key_idx
    end
  end

  describe "with parsed chords-over-words input" do
    test "formats from ChordsOverWords parsed input" do
      cow_input = "C       G\nHello   world"
      {:ok, song} = ChordsOverWordsParser.parse(cow_input)
      result = ChordsOverWordsFormatter.format(song)

      assert result =~ "C"
      assert result =~ "G"
      assert result =~ "Hello"
      assert result =~ "world"
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      result = ChordsOverWordsFormatter.format(song)

      assert result =~ "title: Let It Be"
      assert result =~ "artist: The Beatles"
      assert result =~ "key: C"
      assert result =~ "When I find"
    end
  end
end

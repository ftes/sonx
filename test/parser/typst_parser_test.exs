defmodule Sonx.Parser.TypstParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{ChordLyricsPair, Song, Tag}
  alias Sonx.ChordSheet.Metadata
  alias Sonx.Parser.TypstParser

  describe "preamble" do
    test "ignores #import lines" do
      input = """
      #import "@preview/conchord:0.4.0": chordify
      #show: chordify

      [Am] Hello
      """

      {:ok, song} = TypstParser.parse(input)
      chords = Song.get_chords(song)
      assert chords == ["Am"]
    end

    test "ignores #set lines" do
      input = """
      #set page(height: auto)
      #show: chordify

      [Am] Hello
      """

      {:ok, song} = TypstParser.parse(input)
      chords = Song.get_chords(song)
      assert chords == ["Am"]
    end
  end

  describe "headings" do
    test "parses level 1 heading as title" do
      {:ok, song} = TypstParser.parse("= My Song")
      assert Song.title(song) == "My Song"
    end

    test "parses level 2 heading as subtitle" do
      input = "= My Song\n== The Subtitle"
      {:ok, song} = TypstParser.parse(input)
      assert Song.title(song) == "My Song"
      assert Song.subtitle(song) == "The Subtitle"
    end

    test "parses second level 2 heading as artist" do
      input = "= My Song\n== The Subtitle\n== The Artist"
      {:ok, song} = TypstParser.parse(input)

      metadata = Song.metadata(song)
      assert Metadata.get(metadata, "artist") == "The Artist"
    end

    test "parses level 3 heading as section start" do
      input = "=== Verse 1\n\n[Am] Hello"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "start_of_verse")
      assert tag != nil
      assert tag.value == "Verse 1"
    end

    test "parses chorus section heading" do
      input = "=== Chorus\n\n[Am] Hello"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "start_of_chorus")
      assert tag != nil
    end

    test "parses bridge section heading" do
      input = "=== Bridge\n\n[Em] Over"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "start_of_bridge")
      assert tag != nil
    end

    test "parses unknown section as start_of_part" do
      input = "=== Interlude\n\n[Am] Hello"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "start_of_part")
      assert tag != nil
      assert tag.value == "Interlude"
    end
  end

  describe "meta comments" do
    test "parses key comment" do
      {:ok, song} = TypstParser.parse("// key: C")
      assert Song.key(song) == "C"
    end

    test "parses capo comment" do
      input = "// capo: 3"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "capo")
      assert tag != nil
      assert tag.value == "3"
    end

    test "parses tempo comment" do
      input = "// tempo: 120"
      {:ok, song} = TypstParser.parse(input)

      tag = find_tag(song, "tempo")
      assert tag != nil
      assert tag.value == "120"
    end

    test "ignores non-meta comments" do
      input = "// this is just a comment\n[Am] Hello"
      {:ok, song} = TypstParser.parse(input)
      chords = Song.get_chords(song)
      assert chords == ["Am"]
    end
  end

  describe "chord parsing" do
    test "parses single chord with lyrics" do
      {:ok, song} = TypstParser.parse("[Am] Hello world")

      pair = find_chord_pair(song)
      assert pair.chords == "Am"
      assert pair.lyrics =~ "Hello world"
    end

    test "parses multiple chords on one line" do
      {:ok, song} = TypstParser.parse("[Am] Hello [G] world")

      chords = Song.get_chords(song)
      assert chords == ["Am", "G"]
    end

    test "parses chord-only line (no lyrics)" do
      {:ok, song} = TypstParser.parse("[Am][G][C]")

      chords = Song.get_chords(song)
      assert chords == ["Am", "G", "C"]
    end

    test "parses lyrics before first chord" do
      {:ok, song} = TypstParser.parse("Hello [Am] world")

      line = find_content_line(song)
      [first | _] = line.items
      assert %ChordLyricsPair{chords: "", lyrics: "Hello "} = first
    end

    test "parses complex chord names" do
      {:ok, song} = TypstParser.parse("[C#m7] Hello [Bb/F] world")

      chords = Song.get_chords(song)
      assert "C#m7" in chords
      assert "Bb/F" in chords
    end

    test "strips single leading space from lyrics after chord" do
      {:ok, song} = TypstParser.parse("[Am] Hello [G] world")

      line = find_content_line(song)
      pairs = Enum.filter(line.items, &match?(%ChordLyricsPair{}, &1))
      [first, second] = pairs
      assert first.chords == "Am"
      assert first.lyrics == "Hello "
      assert second.chords == "G"
      assert second.lyrics == "world"
    end
  end

  describe "line continuations" do
    test "strips trailing backslash" do
      input = "[Am] Hello \\\n[G] world"
      {:ok, song} = TypstParser.parse(input)

      chords = Song.get_chords(song)
      assert chords == ["Am", "G"]
    end

    test "does not merge continuation lines" do
      input = "[Am] Line one \\\n[G] Line two"
      {:ok, song} = TypstParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert length(content_lines) == 2
    end
  end

  describe "bracket escaping" do
    test "unescapes doubled square brackets" do
      {:ok, song} = TypstParser.parse("[Am] Hello [[world]]")

      line = find_content_line(song)

      lyrics =
        line.items
        |> Enum.filter(&match?(%ChordLyricsPair{}, &1))
        |> Enum.map_join("", & &1.lyrics)

      assert lyrics =~ "[world]"
    end
  end

  describe "empty input" do
    test "parses empty string" do
      {:ok, song} = TypstParser.parse("")
      assert Enum.all?(song.lines, fn line -> line.items == [] end)
    end

    test "parses whitespace-only" do
      {:ok, song} = TypstParser.parse("   \n   \n   ")
      # Only empty lines
      assert Enum.all?(song.lines, fn line -> line.items == [] end)
    end
  end

  describe "paragraph breaks" do
    test "empty lines create paragraph breaks" do
      input = "[Am] First\n\n[G] Second"
      {:ok, song} = TypstParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert length(content_lines) == 2

      # There should be an empty line between them
      has_empty? = Enum.any?(song.lines, fn line -> line.items == [] end)
      assert has_empty?
    end
  end

  describe "plain lyrics" do
    test "parses line without chords" do
      input = "=== Verse\n\nJust some words"
      {:ok, song} = TypstParser.parse(input)

      line = find_content_line(song)
      assert line != nil
      pair = hd(line.items)
      assert %ChordLyricsPair{chords: "", lyrics: "Just some words"} = pair
    end
  end

  describe "fixture" do
    test "parses simple.typ fixture" do
      input = File.read!("test/support/fixtures/typst/simple.typ")

      {:ok, song} = TypstParser.parse(input)

      assert Song.title(song) == "Let It Be"
      assert Song.key(song) == "C"

      chords = Song.get_chords(song)
      assert "C" in chords
      assert "G" in chords
      assert "Am" in chords
      assert "F" in chords

      verse_tag = find_tag(song, "start_of_verse")
      assert verse_tag != nil
      assert verse_tag.value == "Verse 1"

      chorus_tag = find_tag(song, "start_of_chorus")
      assert chorus_tag != nil
    end
  end

  # --- Helpers ---

  defp find_tag(song, tag_name) do
    Enum.find_value(song.lines, fn line ->
      Enum.find(line.items, fn
        %Tag{name: ^tag_name} -> true
        _ -> false
      end)
    end)
  end

  defp find_chord_pair(song) do
    Enum.find_value(song.lines, fn line ->
      Enum.find(line.items, fn
        %ChordLyricsPair{chords: c} when c != "" -> true
        _ -> false
      end)
    end)
  end

  defp find_content_line(song) do
    Enum.find(song.lines, fn line ->
      Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
    end)
  end
end

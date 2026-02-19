defmodule Sonx.Formatter.TypstFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.ChordLyricsPair
  alias Sonx.ChordSheet.Line
  alias Sonx.ChordSheet.Song
  alias Sonx.Formatter.TypstFormatter
  alias Sonx.Parser.ChordProParser

  describe "preamble" do
    test "includes import and show rule" do
      {:ok, song} = ChordProParser.parse("")
      result = TypstFormatter.format(song)
      assert result =~ ~s(#import "@preview/conchord:0.4.0": chordify)
      assert result =~ "#show: chordify"
    end
  end

  describe "header" do
    test "formats title as level 1 heading" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = TypstFormatter.format(song)
      assert result =~ "= My Song"
    end

    test "formats subtitle as level 2 heading" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{subtitle: The Subtitle}")
      result = TypstFormatter.format(song)
      assert result =~ "= My Song\n== The Subtitle"
    end

    test "formats artist as level 2 heading" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{artist: John Doe}")
      result = TypstFormatter.format(song)
      assert result =~ "= My Song\n== John Doe"
    end

    test "formats title, subtitle, and artist" do
      input = "{title: My Song}\n{subtitle: Sub}\n{artist: Artist}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "= My Song\n== Sub\n== Artist"
    end

    test "omits header when no title" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = TypstFormatter.format(song)
      refute result =~ "= "
    end
  end

  describe "meta comments" do
    test "formats key as comment" do
      {:ok, song} = ChordProParser.parse("{title: Test}\n{key: C}")
      result = TypstFormatter.format(song)
      assert result =~ "// key: C"
    end

    test "formats capo as comment" do
      {:ok, song} = ChordProParser.parse("{title: Test}\n{capo: 3}")
      result = TypstFormatter.format(song)
      assert result =~ "// capo: 3"
    end

    test "formats tempo as comment" do
      {:ok, song} = ChordProParser.parse("{title: Test}\n{tempo: 120}")
      result = TypstFormatter.format(song)
      assert result =~ "// tempo: 120"
    end

    test "formats multiple meta tags" do
      input = "{title: Test}\n{key: C}\n{capo: 2}\n{tempo: 100}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "// key: C"
      assert result =~ "// capo: 2"
      assert result =~ "// tempo: 100"
    end
  end

  describe "inline chords" do
    test "formats chord with lyrics" do
      {:ok, song} = ChordProParser.parse("[Am]Hello [G]world")
      result = TypstFormatter.format(song)
      assert result =~ "[Am] Hello [G] world"
    end

    test "concatenates chord-only pairs into single bracket" do
      {:ok, song} = ChordProParser.parse("[F][C][Dm]")
      result = TypstFormatter.format(song)
      assert result =~ "[F C Dm]"
    end

    test "concatenates trailing chords into single bracket" do
      {:ok, song} = ChordProParser.parse("[C]Whisper words of [G]wisdom, let it [F]be[C/E][Dm][C]")
      result = TypstFormatter.format(song)
      assert result =~ "[F] be[C/E Dm C]"
    end

    test "formats lyrics without chords" do
      {:ok, song} = ChordProParser.parse("Just some words")
      result = TypstFormatter.format(song)
      assert result =~ "Just some words"
    end

    test "formats empty chord with lyrics" do
      {:ok, song} = ChordProParser.parse("Hello [G]world")
      result = TypstFormatter.format(song)
      assert result =~ "Hello [G] world"
    end
  end

  describe "sections" do
    test "formats verse section" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "=== Verse"
      assert result =~ "[C] Hello"
    end

    test "formats verse with label" do
      input = "{start_of_verse: label=\"Verse 1\"}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "=== Verse 1"
    end

    test "formats chorus section" do
      input = "{start_of_chorus}\n[Am]Let it be\n{end_of_chorus}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "=== Chorus"
      assert result =~ "[Am] Let it be"
    end

    test "formats bridge section" do
      input = "{start_of_bridge}\n[Em]Over the bridge\n{end_of_bridge}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "=== Bridge"
    end

    test "does not emit end-of-section tags" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      refute result =~ "end_of"
    end

    test "formats multiple sections" do
      input = """
      {start_of_verse}
      [C]Hello [G]world
      {end_of_verse}
      {start_of_chorus}
      [Am]Let it [F]be
      {end_of_chorus}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "=== Verse"
      assert result =~ "=== Chorus"
    end
  end

  describe "line joining" do
    test "joins content lines with backslash continuation" do
      input = "{start_of_verse}\n[C]Line one\n[G]Line two\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)
      assert result =~ "[C] Line one \\\n[G] Line two"
    end
  end

  describe "comments" do
    test "formats comment tag as Typst comment" do
      {:ok, song} = ChordProParser.parse("{comment: This is a comment}")
      result = TypstFormatter.format(song)
      assert result =~ "// This is a comment"
    end
  end

  describe "escaping" do
    test "escapes square brackets in lyrics" do
      # Build a song with literal brackets in lyrics directly
      song = %Song{
        lines: [
          %Line{
            items: [
              %ChordLyricsPair{chords: "C", lyrics: "Hello [world]", annotation: ""}
            ],
            type: :none
          }
        ]
      }

      result = TypstFormatter.format(song)
      assert result =~ "[C] Hello [[world]]"
    end
  end

  describe "options" do
    test "respects normalize_chords option" do
      {:ok, song} = ChordProParser.parse("[C#]Hello")
      result = TypstFormatter.format(song, normalize_chords: true)
      assert result =~ "[C\\#]"
    end

    test "respects unicode_accidentals option" do
      {:ok, song} = ChordProParser.parse("[C#]Hello")
      result = TypstFormatter.format(song, normalize_chords: true, unicode_accidentals: true)
      assert result =~ "[C♯]"
    end
  end

  describe "chord_diagrams option" do
    test "adds sized-chordlib import and context call with defaults" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = TypstFormatter.format(song, chord_diagrams: true)

      assert result =~ ~s(#import "@preview/conchord:0.4.0": chordify, sized-chordlib)
      assert result =~ "#context sized-chordlib(N: 4)"
      refute result =~ "width"
    end

    test "does not include sized-chordlib by default" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = TypstFormatter.format(song)

      refute result =~ "sized-chordlib"
    end

    test "accepts custom N via keyword list" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = TypstFormatter.format(song, chord_diagrams: [n: 6])

      assert result =~ "#context sized-chordlib(N: 6)"
      refute result =~ "width"
    end

    test "accepts custom N and width via keyword list" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = TypstFormatter.format(song, chord_diagrams: [n: 6, width: "400pt"])

      assert result =~ "#context sized-chordlib(N: 6, width: 400pt)"
    end

    test "raises on invalid diagram options" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")

      assert_raise NimbleOptions.ValidationError, fn ->
        TypstFormatter.format(song, chord_diagrams: [n: -1])
      end
    end

    test "uses #h(2em) spacing instead of concatenation for chord-only pairs" do
      {:ok, song} = ChordProParser.parse("[F][C][Dm]")
      result = TypstFormatter.format(song, chord_diagrams: true)
      assert result =~ "[F]#h(2em) [C]#h(2em) [Dm]#h(2em)"
      refute result =~ "[F C Dm]"
    end
  end

  describe "empty song" do
    test "formats empty song with just preamble" do
      {:ok, song} = ChordProParser.parse("")
      result = TypstFormatter.format(song)
      assert result == "#import \"@preview/conchord:0.4.0\": chordify\n#show: chordify"
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      input = File.read!("test/support/fixtures/chord_pro/simple.cho")
      {:ok, song} = ChordProParser.parse(input)
      result = TypstFormatter.format(song)

      assert result =~ "= Let It Be"
      assert result =~ "== Beatles"
      assert result =~ "== The Beatles"
      assert result =~ "=== Verse 1"
      assert result =~ "=== Chorus"
      assert result =~ "[C]"
      assert result =~ "[G]"
      assert result =~ "// key: C"
    end
  end
end

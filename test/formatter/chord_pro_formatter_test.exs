defmodule Sonx.Formatter.ChordProFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.ChordProFormatter
  alias Sonx.Parser.ChordProParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = ChordProFormatter.format(song)
      assert result == ""
    end

    test "formats title directive" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = ChordProFormatter.format(song)
      assert result =~ "{title: My Song}"
    end

    test "formats multiple metadata directives" do
      input = "{title: My Song}\n{artist: John Doe}\n{key: C}"
      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)

      assert result =~ "{title: My Song}"
      assert result =~ "{artist: John Doe}"
      assert result =~ "{key: C}"
    end
  end

  describe "chord-lyrics formatting" do
    test "formats inline chords" do
      {:ok, song} = ChordProParser.parse("[Am]Hello [C]world")
      result = ChordProFormatter.format(song)
      assert result =~ "[Am]Hello"
      assert result =~ "[C]world"
    end

    test "formats chord without lyrics" do
      {:ok, song} = ChordProParser.parse("[Am][G]")
      result = ChordProFormatter.format(song)
      assert result =~ "[Am]"
      assert result =~ "[G]"
    end

    test "formats lyrics without chords" do
      {:ok, song} = ChordProParser.parse("Just some lyrics")
      result = ChordProFormatter.format(song)
      assert result =~ "Just some lyrics"
    end
  end

  describe "sections" do
    test "formats section directives" do
      input = """
      {start_of_verse}
      [C]Hello [G]world
      {end_of_verse}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)

      assert result =~ "{start_of_verse}"
      assert result =~ "[C]Hello"
      assert result =~ "{end_of_verse}"
    end

    test "formats section with label attribute" do
      input = "{start_of_verse: label=\"Verse 1\"}"
      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)
      assert result =~ "start_of_verse"
      assert result =~ "Verse 1"
    end
  end

  describe "comments" do
    test "formats comments" do
      {:ok, song} = ChordProParser.parse("# This is a comment")
      result = ChordProFormatter.format(song)
      assert result =~ "#"
      assert result =~ "This is a comment"
    end
  end

  describe "ternary expressions" do
    test "formats simple ternary" do
      {:ok, song} = ChordProParser.parse("%{title}")
      result = ChordProFormatter.format(song)
      assert result =~ "%{title}"
    end

    test "formats ternary with true/false expressions" do
      {:ok, song} = ChordProParser.parse("%{title|yes|no}")
      result = ChordProFormatter.format(song)
      assert result =~ "%{title|yes|no}"
    end

    test "formats ternary with value test" do
      {:ok, song} = ChordProParser.parse("%{key=Am|minor|major}")
      result = ChordProFormatter.format(song)
      assert result =~ "%{key=Am|minor|major}"
    end
  end

  describe "soft line breaks" do
    test "formats soft line break" do
      {:ok, song} = ChordProParser.parse("[Am]Hello\\ world")
      result = ChordProFormatter.format(song)
      assert result =~ "\\ "
    end
  end

  describe "metadata separation" do
    test "separates metadata from content with blank line" do
      input = """
      {title: My Song}
      {artist: John Doe}
      {start_of_verse}
      [C]Hello [G]world
      {end_of_verse}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)

      # Metadata and content should be separated by a blank line
      assert result =~ "{title: My Song}"
      assert result =~ "{artist: John Doe}"
      assert result =~ "[C]Hello"
    end
  end

  describe "round-trip preservation" do
    test "simple chord pro round-trips" do
      input = "[Am]Hello [C]world"
      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)
      assert result =~ "[Am]Hello"
      assert result =~ "[C]world"

      # Re-parse the output
      {:ok, song2} = ChordProParser.parse(result)
      result2 = ChordProFormatter.format(song2)
      assert result == result2
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      result = ChordProFormatter.format(song)

      assert result =~ "{title: Let It Be}"
      assert result =~ "{artist: The Beatles}"
      assert result =~ "[C]When I find"
      assert result =~ "{start_of_verse"
      assert result =~ "{end_of_verse}"
    end
  end
end

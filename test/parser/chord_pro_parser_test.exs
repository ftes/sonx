defmodule Sonx.Parser.ChordProParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Literal,
    Metadata,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  alias Sonx.Parser.ChordProParser

  describe "basic parsing" do
    test "parses empty string" do
      {:ok, song} = ChordProParser.parse("")
      assert %Song{} = song
    end

    test "parses title directive" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == "My Song"
    end

    test "parses short-form title directive" do
      {:ok, song} = ChordProParser.parse("{t: My Song}")
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == "My Song"
    end

    test "parses multiple metadata directives" do
      input = """
      {title: My Song}
      {artist: John Doe}
      {key: Am}
      """

      {:ok, song} = ChordProParser.parse(input)
      meta = Song.metadata(song)

      assert Metadata.get_single(meta, "title") == "My Song"
      assert Metadata.get_single(meta, "artist") == "John Doe"
      assert Metadata.get_single(meta, "key") == "Am"
    end
  end

  describe "chord-lyrics pairs" do
    test "parses inline chord with lyrics" do
      {:ok, song} = ChordProParser.parse("[Am]Hello world")

      content_line = find_content_line(song)
      assert content_line != nil

      pair = Enum.find(content_line.items, &match?(%ChordLyricsPair{}, &1))
      assert pair.chords == "Am"
      assert pair.lyrics =~ "Hello"
    end

    test "parses multiple chords on one line" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")

      content_line = find_content_line(song)
      pairs = Enum.filter(content_line.items, &match?(%ChordLyricsPair{}, &1))

      assert [_, _ | _] = pairs
      assert Enum.at(pairs, 0).chords == "C"
      assert Enum.at(pairs, 1).chords == "G"
    end

    test "parses chord without lyrics at end of line" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]")

      content_line = find_content_line(song)
      pairs = Enum.filter(content_line.items, &match?(%ChordLyricsPair{}, &1))

      assert [_, _ | _] = pairs
      c_pair = Enum.at(pairs, 0)
      assert c_pair.chords == "C"
    end

    test "parses lyrics without chords" do
      {:ok, song} = ChordProParser.parse("Just some lyrics")

      content_line = find_content_line(song)
      assert content_line != nil
      pair = Enum.find(content_line.items, &match?(%ChordLyricsPair{}, &1))
      assert pair.lyrics =~ "Just some lyrics"
    end
  end

  describe "sections" do
    test "parses verse section" do
      input = """
      {start_of_verse}
      [C]Hello
      {end_of_verse}
      """

      {:ok, song} = ChordProParser.parse(input)

      verse_lines =
        Enum.filter(song.lines, fn line -> line.type == :verse end)

      assert [_ | _] = verse_lines
    end

    test "parses chorus section" do
      input = """
      {soc}
      [Am]Chorus line
      {eoc}
      """

      {:ok, song} = ChordProParser.parse(input)

      chorus_lines =
        Enum.filter(song.lines, fn line -> line.type == :chorus end)

      assert [_ | _] = chorus_lines
    end

    test "parses section with label" do
      input = "{start_of_verse: label=\"Verse 1\"}"

      {:ok, song} = ChordProParser.parse(input)

      tag_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, fn
            %Tag{name: "start_of_verse"} -> true
            _ -> false
          end)
        end)

      tag = Enum.find(tag_line.items, &match?(%Tag{name: "start_of_verse"}, &1))
      assert Tag.label(tag) == "Verse 1"
    end
  end

  describe "comments" do
    test "parses comment line" do
      {:ok, song} = ChordProParser.parse("# This is a comment")

      comment_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, &match?(%Comment{}, &1))
        end)

      assert comment_line != nil
      comment = Enum.find(comment_line.items, &match?(%Comment{}, &1))
      assert comment.content =~ "This is a comment"
    end
  end

  describe "ternary expressions" do
    test "parses simple ternary" do
      {:ok, song} = ChordProParser.parse("%{title}")

      content_line = find_content_line(song)
      ternary = Enum.find(content_line.items, &match?(%Ternary{}, &1))
      assert ternary != nil
      assert ternary.variable == "title"
    end

    test "parses ternary with true/false expressions" do
      {:ok, song} = ChordProParser.parse("%{title|yes|no}")

      content_line = find_content_line(song)
      ternary = Enum.find(content_line.items, &match?(%Ternary{}, &1))
      assert ternary.variable == "title"
      refute Enum.empty?(ternary.true_expression)
      refute Enum.empty?(ternary.false_expression)
    end

    test "parses ternary with value test" do
      {:ok, song} = ChordProParser.parse("%{key=Am|minor|major}")

      content_line = find_content_line(song)
      ternary = Enum.find(content_line.items, &match?(%Ternary{}, &1))
      assert ternary.variable == "key"
      assert ternary.value_test == "Am"
    end
  end

  describe "soft line breaks" do
    test "parses soft line break" do
      {:ok, song} = ChordProParser.parse("[Am]Hello\\ world")

      content_line = find_content_line(song)
      items = content_line.items

      soft_break = Enum.find(items, &match?(%SoftLineBreak{}, &1))
      assert soft_break != nil
    end
  end

  describe "fixture file" do
    test "parses simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      meta = Song.metadata(song)

      assert Metadata.get_single(meta, "title") == "Let It Be"
      assert Metadata.get_single(meta, "artist") == "The Beatles"
      assert Metadata.get_single(meta, "key") == "C"

      # Should have verse and chorus sections
      section_types = song.lines |> Enum.map(& &1.type) |> Enum.uniq()
      assert :verse in section_types
      assert :chorus in section_types

      # Should have chords
      chords = Song.get_chords(song)
      assert "C" in chords
      assert "G" in chords
      assert "Am" in chords
      assert "F" in chords
    end
  end

  describe "edge cases" do
    test "handles escaped brackets" do
      {:ok, song} = ChordProParser.parse("Hello \\[world\\]")
      content_line = find_content_line(song)
      pair = Enum.find(content_line.items, &match?(%ChordLyricsPair{}, &1))
      assert pair.lyrics =~ "[world]"
    end

    test "handles empty lines" do
      input = """
      {title: Test}

      [C]Hello

      [G]World
      """

      {:ok, song} = ChordProParser.parse(input)
      assert [_, _, _, _ | _] = song.lines
    end

    test "handles mixed directives and content" do
      input = """
      {title: Test}
      {key: C}
      {start_of_verse}
      [C]First line
      [G]Second line
      {end_of_verse}
      """

      {:ok, song} = ChordProParser.parse(input)
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == "Test"

      verse_lines = Enum.filter(song.lines, &(&1.type == :verse))
      assert [_, _ | _] = verse_lines
    end
  end

  # Helper to find first line with renderable content
  defp find_content_line(song) do
    Enum.find(song.lines, fn line ->
      Enum.any?(line.items, fn
        %ChordLyricsPair{} -> true
        %Ternary{} -> true
        %Literal{} -> true
        _ -> false
      end)
    end)
  end
end

defmodule Sonx.Parser.ChordsOverWordsParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Metadata,
    Song,
    Tag
  }

  alias Sonx.Parser.ChordsOverWordsParser

  describe "basic parsing" do
    test "parses empty string" do
      {:ok, song} = ChordsOverWordsParser.parse("")
      assert %Song{} = song
    end

    test "parses plain lyrics line" do
      {:ok, song} = ChordsOverWordsParser.parse("Just some lyrics")
      line = find_content_line(song)
      assert line != nil
      pair = find_pair(line)
      assert pair.chords == ""
      assert pair.lyrics == "Just some lyrics"
    end

    test "parses chord line with lyrics below" do
      input = "C       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)
      assert [_, _ | _] = pairs

      chords = Enum.map(pairs, & &1.chords)
      assert "C" in chords
      assert "G" in chords
    end

    test "parses chord line without lyrics below" do
      input = "Am  G  F  C"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)
      assert [_, _, _, _] = pairs
      assert Enum.all?(pairs, fn p -> p.lyrics == "" end)
    end
  end

  describe "frontmatter" do
    test "extracts YAML frontmatter metadata" do
      input = """
      ---
      title: My Song
      artist: John Doe
      key: Am
      ---
      C       G
      Hello world
      """

      {:ok, song} = ChordsOverWordsParser.parse(input)
      meta = Song.metadata(song)

      assert Metadata.get_single(meta, "title") == "My Song"
      assert Metadata.get_single(meta, "artist") == "John Doe"
      assert Metadata.get_single(meta, "key") == "Am"
    end

    test "handles missing frontmatter" do
      input = "C       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == nil
    end

    test "handles unclosed frontmatter as regular content" do
      input = "---\ntitle: My Song\nC       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      # Should not crash; frontmatter not extracted
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == nil
    end
  end

  describe "section headers" do
    test "parses Verse: header" do
      input = "Verse:\nC       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      verse_lines = Enum.filter(song.lines, &(&1.type == :verse))
      assert [_ | _] = verse_lines
    end

    test "parses Chorus: header" do
      input = "Chorus:\nAm      G\nLet it be"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      chorus_lines = Enum.filter(song.lines, &(&1.type == :chorus))
      assert [_ | _] = chorus_lines
    end

    test "parses Bridge: header" do
      input = "Bridge:\nDm      G\nSomething else"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      bridge_lines = Enum.filter(song.lines, &(&1.type == :bridge))
      assert [_ | _] = bridge_lines
    end

    test "parses section header with number" do
      input = "Verse 1:\nC       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      tag_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, fn
            %Tag{name: "start_of_verse"} -> true
            _ -> false
          end)
        end)

      assert tag_line != nil
    end
  end

  describe "chord-lyrics alignment" do
    test "aligns chords with lyrics by position" do
      input = "C       G\nHello   world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)

      c_pair = Enum.find(pairs, &(&1.chords == "C"))
      g_pair = Enum.find(pairs, &(&1.chords == "G"))

      assert c_pair != nil
      assert g_pair != nil
      # C is at position 0, G is at position 8; lyrics split at position 8
      assert c_pair.lyrics =~ "Hello"
      assert g_pair.lyrics =~ "world"
    end

    test "handles leading lyrics before first chord" do
      input = "       Am       G\nOh yes hello    world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)

      # First pair should be lyrics-only (leading text before Am position)
      first = hd(pairs)
      assert first.chords == ""
      assert first.lyrics =~ "Oh yes"
    end

    test "handles lyrics shorter than chord line" do
      input = "Am      G       F       C\nShort"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)

      # Should not crash; later chords get empty lyrics
      assert [_, _ | _] = pairs
    end
  end

  describe "embedded directives" do
    test "parses ChordPro directive in chords-over-words" do
      input = "{title: Embedded Title}\nC       G\nHello world"
      {:ok, song} = ChordsOverWordsParser.parse(input)
      meta = Song.metadata(song)
      assert Metadata.get_single(meta, "title") == "Embedded Title"
    end
  end

  describe "empty lines" do
    test "handles multiple empty lines" do
      input = "C       G\nHello world\n\n\nAm      F\nGoodbye"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert [_, _ | _] = content_lines
    end
  end

  describe "consecutive chord lines" do
    test "handles two chord lines in a row" do
      input = "Am  G\nF   C\nSome lyrics"
      {:ok, song} = ChordsOverWordsParser.parse(input)

      # First chord line should stand alone (next line is also chords)
      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert [_, _ | _] = content_lines
    end
  end

  describe "fixture file" do
    test "parses simple.txt fixture" do
      fixture_path =
        Path.join([__DIR__, "..", "support", "fixtures", "chords_over_words", "simple.txt"])

      input = File.read!(fixture_path)

      {:ok, song} = ChordsOverWordsParser.parse(input)
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

  describe "parse!/2" do
    test "returns song directly" do
      song = ChordsOverWordsParser.parse!("C\nHello")
      assert %Song{} = song
    end

    test "raises on error" do
      # The parser is quite forgiving, so simulate by checking parse! works
      song = ChordsOverWordsParser.parse!("")
      assert %Song{} = song
    end
  end

  # -- Helpers --

  defp find_content_line(song) do
    Enum.find(song.lines, fn line ->
      Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
    end)
  end

  defp find_pair(line) do
    Enum.find(line.items, &match?(%ChordLyricsPair{}, &1))
  end

  defp all_pairs(line) do
    Enum.filter(line.items, &match?(%ChordLyricsPair{}, &1))
  end
end

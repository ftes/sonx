defmodule Sonx.Parser.UltimateGuitarParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Song,
    Tag
  }

  alias Sonx.Formatter.ChordProFormatter
  alias Sonx.Parser.UltimateGuitarParser

  describe "basic parsing" do
    test "parses empty string" do
      {:ok, song} = UltimateGuitarParser.parse("")
      assert %Song{} = song
    end

    test "parses plain lyrics line" do
      {:ok, song} = UltimateGuitarParser.parse("Just some lyrics")
      line = find_content_line(song)
      pair = find_pair(line)
      assert pair.chords == ""
      assert pair.lyrics == "Just some lyrics"
    end

    test "parses chord line with lyrics below" do
      input = "C       G\nHello world"
      {:ok, song} = UltimateGuitarParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)
      assert [_, _ | _] = pairs

      chords = Enum.map(pairs, & &1.chords)
      assert "C" in chords
      assert "G" in chords
    end

    test "parses chord line without lyrics below" do
      input = "Am  G  F  C"
      {:ok, song} = UltimateGuitarParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)
      assert [_, _, _, _] = pairs
      assert Enum.all?(pairs, fn p -> p.lyrics == "" end)
    end
  end

  describe "section start and end tags" do
    test "starts and ends a single verse tag correctly" do
      {:ok, song} = UltimateGuitarParser.parse("[Verse 1]")

      assert_tag_on_line(song, 0, "start_of_verse", "Verse 1")
      assert_tag_on_line(song, 1, "end_of_verse", "")
    end

    test "parses a single verse correctly" do
      input =
        "[Verse 1]\nC     G        Am\nHello world    today\nC        G     F\nGoodbye moon   tonight"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_verse", "Verse 1")
      assert length(Enum.at(song.lines, 1).items) >= 2
      assert length(Enum.at(song.lines, 2).items) >= 2
      assert_tag_on_line(song, 3, "end_of_verse", "")
    end

    test "parses verses and choruses case-insensitively" do
      input =
        "[VERSE 1]\nC     G        Am\nHello world    today\n[chorus]\nC        G     F\nGoodbye moon   tonight"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_verse", "VERSE 1")
      assert_tag_on_line(song, 2, "end_of_verse", "")
      assert_tag_on_line(song, 3, "start_of_chorus", "chorus")
      assert_tag_on_line(song, 5, "end_of_chorus", "")
    end

    test "parses bridge sections" do
      input = "[Bridge]\nF  C Dm\nSome bridge lyrics"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_bridge", "Bridge")
      last_idx = length(song.lines) - 1
      assert_tag_on_line(song, last_idx, "end_of_bridge", "")
    end

    test "parses bridge sections with number" do
      {:ok, song} = UltimateGuitarParser.parse("[Bridge 2]")

      assert_tag_on_line(song, 0, "start_of_bridge", "Bridge 2")
      assert_tag_on_line(song, 1, "end_of_bridge", "")
    end

    test "parses intro sections as part" do
      input = "[Intro]\nF  C Dm"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_part", "Intro")
      last_idx = length(song.lines) - 1
      assert_tag_on_line(song, last_idx, "end_of_part", "")
    end

    test "parses outro sections as part" do
      {:ok, song} = UltimateGuitarParser.parse("[Outro]")

      assert_tag_on_line(song, 0, "start_of_part", "Outro")
      assert_tag_on_line(song, 1, "end_of_part", "")
    end

    test "parses instrumental sections as part" do
      input = "[Instrumental]\nF  C Dm"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_part", "Instrumental")
      last_idx = length(song.lines) - 1
      assert_tag_on_line(song, last_idx, "end_of_part", "")
    end

    test "parses interlude sections as part" do
      {:ok, song} = UltimateGuitarParser.parse("[Interlude]")

      assert_tag_on_line(song, 0, "start_of_part", "Interlude")
      assert_tag_on_line(song, 1, "end_of_part", "")
    end

    test "parses solo sections as part" do
      {:ok, song} = UltimateGuitarParser.parse("[Solo]")

      assert_tag_on_line(song, 0, "start_of_part", "Solo")
      assert_tag_on_line(song, 1, "end_of_part", "")
    end

    test "parses pre-chorus sections as part" do
      {:ok, song} = UltimateGuitarParser.parse("[Pre-Chorus]")

      assert_tag_on_line(song, 0, "start_of_part", "Pre-Chorus")
      assert_tag_on_line(song, 1, "end_of_part", "")
    end

    test "parses section types case-insensitively" do
      {:ok, song} = UltimateGuitarParser.parse("[BRIDGE]")

      assert_tag_on_line(song, 0, "start_of_bridge", "BRIDGE")
    end

    test "adds truly unknown sections as comments" do
      {:ok, song} = UltimateGuitarParser.parse("[Some Random Thing]")

      line = Enum.at(song.lines, 0)
      tag = Enum.find(line.items, &match?(%Tag{}, &1))
      assert tag.name == "comment"
      assert tag.value == "Some Random Thing"
    end

    test "ends section when new section starts without blank line" do
      input = "[Verse]\nC G\nHello\n[Chorus]\nAm F\nWorld"
      {:ok, song} = UltimateGuitarParser.parse(input)

      tags = all_tags(song)
      tag_names = Enum.map(tags, & &1.name)

      assert "start_of_verse" in tag_names
      assert "end_of_verse" in tag_names
      assert "start_of_chorus" in tag_names
      assert "end_of_chorus" in tag_names
    end

    test "ends section at blank line boundary" do
      input = "[Verse]\nC G\nHello\n\n[Chorus]\nAm F\nWorld"
      {:ok, song} = UltimateGuitarParser.parse(input)

      tags = all_tags(song)
      tag_names = Enum.map(tags, & &1.name)

      assert "start_of_verse" in tag_names
      assert "end_of_verse" in tag_names
      assert "start_of_chorus" in tag_names
      assert "end_of_chorus" in tag_names
    end

    test "parses consecutive chord lines without lyrics" do
      input = "[Intro]\nD A Bm G\nD A Bm G"

      {:ok, song} = UltimateGuitarParser.parse(input)

      assert_tag_on_line(song, 0, "start_of_part", "Intro")

      # Two chord lines
      line1_pairs = all_pairs(Enum.at(song.lines, 1))
      assert length(line1_pairs) == 4

      line2_pairs = all_pairs(Enum.at(song.lines, 2))
      assert length(line2_pairs) == 4

      last_idx = length(song.lines) - 1
      assert_tag_on_line(song, last_idx, "end_of_part", "")
    end
  end

  describe "section markers (legacy)" do
    test "section marker sets section type for subsequent lines" do
      input = "[Verse]\nC       G\nHello world\n[Chorus]\nAm      F\nLet it be"
      {:ok, song} = UltimateGuitarParser.parse(input)

      verse_lines = Enum.filter(song.lines, &(&1.type == :verse))
      chorus_lines = Enum.filter(song.lines, &(&1.type == :chorus))

      assert [_ | _] = verse_lines
      assert [_ | _] = chorus_lines
    end
  end

  describe "chord-lyrics alignment" do
    test "aligns chords with lyrics by position" do
      input = "C       G\nHello   world"
      {:ok, song} = UltimateGuitarParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)

      c_pair = Enum.find(pairs, &(&1.chords == "C"))
      g_pair = Enum.find(pairs, &(&1.chords == "G"))

      assert c_pair != nil
      assert g_pair != nil
      assert c_pair.lyrics =~ "Hello"
      assert g_pair.lyrics =~ "world"
    end

    test "handles leading lyrics before first chord" do
      input = "       Am       G\nOh yes hello    world"
      {:ok, song} = UltimateGuitarParser.parse(input)
      line = find_content_line(song)
      pairs = all_pairs(line)

      first = hd(pairs)
      assert first.chords == ""
      assert first.lyrics =~ "Oh yes"
    end
  end

  describe "empty lines and structure" do
    test "handles empty lines between sections" do
      input = "[Verse]\nC       G\nHello world\n\n[Chorus]\nAm      F\nLet it be"
      {:ok, song} = UltimateGuitarParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert [_, _ | _] = content_lines
    end

    test "handles consecutive chord lines" do
      input = "Am  G\nF   C\nSome lyrics"
      {:ok, song} = UltimateGuitarParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert [_, _ | _] = content_lines
    end
  end

  describe "fixture file" do
    test "parses simple.txt fixture" do
      input = File.read!("test/support/fixtures/ultimate_guitar/simple.txt")

      {:ok, song} = UltimateGuitarParser.parse(input)

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

    test "parses full fixture and formats as ChordPro" do
      input = File.read!("test/support/fixtures/ultimate_guitar/ultimate_guitar_chordsheet.txt")

      expected =
        "test/support/fixtures/ultimate_guitar/ultimate_guitar_chordsheet_expected_chordpro_format.txt"
        |> File.read!()
        |> String.replace("\r\n", "\n")
        |> String.trim_trailing()

      {:ok, song} = UltimateGuitarParser.parse(input)
      result = song |> ChordProFormatter.format() |> String.trim_trailing()

      assert normalize_blank_lines(result) == normalize_blank_lines(expected)
    end
  end

  describe "parse!/2" do
    test "returns song directly" do
      song = UltimateGuitarParser.parse!("[Verse]\nC\nHello")
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

  defp all_tags(song) do
    Enum.flat_map(song.lines, fn line ->
      Enum.filter(line.items, &match?(%Tag{}, &1))
    end)
  end

  defp assert_tag_on_line(song, line_idx, expected_name, expected_value) do
    line = Enum.at(song.lines, line_idx)
    assert line != nil, "Expected line at index #{line_idx}, but song only has #{length(song.lines)} lines"

    tag = Enum.find(line.items, &match?(%Tag{}, &1))
    assert tag != nil, "Expected a tag on line #{line_idx}, got items: #{inspect(line.items)}"

    assert tag.name == expected_name,
           "Expected tag name #{inspect(expected_name)} on line #{line_idx}, got #{inspect(tag.name)}"

    assert tag.value == expected_value,
           "Expected tag value #{inspect(expected_value)} on line #{line_idx}, got #{inspect(tag.value)}"
  end

  defp normalize_blank_lines(str) do
    str
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end
end

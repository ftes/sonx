defmodule Sonx.Parser.UltimateGuitarParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Song,
    Tag
  }

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

  describe "section markers" do
    test "parses [Verse] marker" do
      input = "[Verse]\nC       G\nHello world"
      {:ok, song} = UltimateGuitarParser.parse(input)

      verse_lines = Enum.filter(song.lines, &(&1.type == :verse))
      assert [_ | _] = verse_lines
    end

    test "parses [Chorus] marker" do
      input = "[Chorus]\nAm      G\nLet it be"
      {:ok, song} = UltimateGuitarParser.parse(input)

      chorus_lines = Enum.filter(song.lines, &(&1.type == :chorus))
      assert [_ | _] = chorus_lines
    end

    test "parses [Bridge] marker" do
      input = "[Bridge]\nDm      G\nSomething else"
      {:ok, song} = UltimateGuitarParser.parse(input)

      bridge_lines = Enum.filter(song.lines, &(&1.type == :bridge))
      assert [_ | _] = bridge_lines
    end

    test "parses [Verse 1] marker with number" do
      input = "[Verse 1]\nC       G\nHello world"
      {:ok, song} = UltimateGuitarParser.parse(input)

      tag_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, fn
            %Tag{name: "start_of_verse"} -> true
            _ -> false
          end)
        end)

      assert tag_line != nil
    end

    test "parses [Intro] as part section" do
      input = "[Intro]\nAm  G  F  C"
      {:ok, song} = UltimateGuitarParser.parse(input)

      tag_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, fn
            %Tag{name: "start_of_part"} -> true
            _ -> false
          end)
        end)

      assert tag_line != nil
    end

    test "parses [Solo] as part section" do
      input = "[Solo]\nAm  G  F  C"
      {:ok, song} = UltimateGuitarParser.parse(input)

      tag_line =
        Enum.find(song.lines, fn line ->
          Enum.any?(line.items, fn
            %Tag{name: "start_of_part"} -> true
            _ -> false
          end)
        end)

      assert tag_line != nil
    end

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
      fixture_path =
        Path.join([__DIR__, "..", "support", "fixtures", "ultimate_guitar", "simple.txt"])

      input = File.read!(fixture_path)

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
end

defmodule Sonx.RoundTripTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.Metadata
  alias Sonx.ChordSheet.Song
  alias Sonx.Formatter.{ChordProFormatter, ChordsOverWordsFormatter, TextFormatter}
  alias Sonx.Parser.{ChordProParser, ChordsOverWordsParser, UltimateGuitarParser}

  describe "ChordPro round-trip" do
    test "parse → format → parse produces same chords" do
      input = "[Am]Hello [C]world [G]today"
      {:ok, song1} = ChordProParser.parse(input)
      output = ChordProFormatter.format(song1)
      {:ok, song2} = ChordProParser.parse(output)

      assert Song.get_chords(song1) == Song.get_chords(song2)
    end

    test "parse → format → parse preserves metadata" do
      input = "{title: My Song}\n{artist: John}\n{key: C}\n[Am]Hello [G]world"
      {:ok, song1} = ChordProParser.parse(input)
      output = ChordProFormatter.format(song1)
      {:ok, song2} = ChordProParser.parse(output)

      meta1 = Song.metadata(song1)
      meta2 = Song.metadata(song2)

      assert Metadata.get_single(meta1, "title") ==
               Metadata.get_single(meta2, "title")

      assert Metadata.get_single(meta1, "artist") ==
               Metadata.get_single(meta2, "artist")

      assert Metadata.get_single(meta1, "key") ==
               Metadata.get_single(meta2, "key")
    end

    test "format → parse → format is stable (idempotent)" do
      input = "[Am]Hello [C]world"
      {:ok, song1} = ChordProParser.parse(input)
      output1 = ChordProFormatter.format(song1)
      {:ok, song2} = ChordProParser.parse(output1)
      output2 = ChordProFormatter.format(song2)

      assert output1 == output2
    end
  end

  describe "cross-format: UltimateGuitar → ChordPro" do
    test "preserves chords through conversion" do
      ug_input = "[Verse]\nC       G\nHello   world\n\n[Chorus]\nAm      F\nLet it be"
      {:ok, song} = UltimateGuitarParser.parse(ug_input)
      chord_pro_output = ChordProFormatter.format(song)

      {:ok, song2} = ChordProParser.parse(chord_pro_output)
      chords = Song.get_chords(song2)

      assert "C" in chords
      assert "G" in chords
      assert "Am" in chords
      assert "F" in chords
    end
  end

  describe "cross-format: ChordsOverWords → ChordPro" do
    test "preserves chords through conversion" do
      cow_input = "C       G\nHello   world"
      {:ok, song} = ChordsOverWordsParser.parse(cow_input)
      chord_pro_output = ChordProFormatter.format(song)

      {:ok, song2} = ChordProParser.parse(chord_pro_output)
      chords = Song.get_chords(song2)

      assert "C" in chords
      assert "G" in chords
    end
  end

  describe "cross-format: ChordPro → Text → content preserved" do
    test "text output contains chords and lyrics" do
      input = "{title: Test}\n[Am]Hello [G]world"
      {:ok, song} = ChordProParser.parse(input)
      text = TextFormatter.format(song)

      assert text =~ "Test"
      assert text =~ "Am"
      assert text =~ "G"
      assert text =~ "Hello"
      assert text =~ "world"
    end
  end

  describe "cross-format: ChordPro → ChordsOverWords" do
    test "preserves metadata and chords" do
      input = "{title: My Song}\n{key: C}\n[Am]Hello [G]world"
      {:ok, song} = ChordProParser.parse(input)
      cow_output = ChordsOverWordsFormatter.format(song)

      assert cow_output =~ "title: My Song"
      assert cow_output =~ "key: C"
      assert cow_output =~ "Am"
      assert cow_output =~ "Hello"
    end
  end

  describe "fixture round-trips" do
    test "simple.cho ChordPro round-trip" do
      fixture_path = Path.join(["test", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song1} = ChordProParser.parse(input)
      output = ChordProFormatter.format(song1)
      {:ok, song2} = ChordProParser.parse(output)

      assert Song.get_chords(song1) == Song.get_chords(song2)
      assert Song.title(song1) == Song.title(song2)
      assert Song.key(song1) == Song.key(song2)
    end
  end
end

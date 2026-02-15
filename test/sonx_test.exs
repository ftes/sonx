defmodule SonxTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.Metadata
  alias Sonx.ChordSheet.Song

  doctest Sonx

  describe "parse/3" do
    test "parses ChordPro format" do
      {:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\n[Am]Hello")
      assert Sonx.title(song) == "My Song"
    end

    test "parses ChordsOverWords format" do
      {:ok, song} = Sonx.parse(:chords_over_words, "Am\nHello")
      assert %Song{} = song
    end

    test "parses UltimateGuitar format" do
      {:ok, song} = Sonx.parse(:ultimate_guitar, "[Verse]\nAm\nHello")
      assert %Song{} = song
    end
  end

  describe "parse!/3" do
    test "returns song directly" do
      song = Sonx.parse!(:chord_pro, "[Am]Hello")
      assert %Song{} = song
    end
  end

  describe "format/3" do
    setup do
      {:ok, song} = Sonx.parse(:chord_pro, "{title: Test}\n[Am]Hello [G]world")
      %{song: song}
    end

    test "formats as text", %{song: song} do
      result = Sonx.format(:text, song)
      assert result =~ "Am"
      assert result =~ "Hello"
    end

    test "formats as ChordPro", %{song: song} do
      result = Sonx.format(:chord_pro, song)
      assert result =~ "[Am]Hello"
    end

    test "formats as ChordsOverWords", %{song: song} do
      result = Sonx.format(:chords_over_words, song)
      assert result =~ "title: Test"
      assert result =~ "Am"
    end

    test "formats as HTML div", %{song: song} do
      result = Sonx.format(:html_div, song)
      assert result =~ "<div class=\"chord\">Am</div>"
    end

    test "formats as HTML table", %{song: song} do
      result = Sonx.format(:html_table, song)
      assert result =~ "<td class=\"chord\">Am</td>"
    end
  end

  describe "chord operations" do
    test "transpose" do
      song = Sonx.parse!(:chord_pro, "{key: C}\n[C]Hello [G]world")
      transposed = Sonx.transpose(song, 2)
      assert Sonx.key(transposed) == "D"
    end

    test "change_key" do
      song = Sonx.parse!(:chord_pro, "{key: C}\n[C]Hello [Am]world")
      changed = Sonx.change_key(song, "G")
      assert Sonx.key(changed) == "G"
      assert "G" in Sonx.get_chords(changed)
    end

    test "use_accidental" do
      song = Sonx.parse!(:chord_pro, "[C#]Hello")
      flatted = Sonx.use_accidental(song, :flat)
      assert "Db" in Sonx.get_chords(flatted)
    end
  end

  describe "metadata" do
    test "returns metadata" do
      song = Sonx.parse!(:chord_pro, "{title: My Song}\n{key: Am}")
      meta = Sonx.metadata(song)
      assert Metadata.get_single(meta, "title") == "My Song"
    end

    test "title" do
      song = Sonx.parse!(:chord_pro, "{title: My Song}")
      assert Sonx.title(song) == "My Song"
    end

    test "key" do
      song = Sonx.parse!(:chord_pro, "{key: Am}")
      assert Sonx.key(song) == "Am"
    end

    test "get_chords" do
      song = Sonx.parse!(:chord_pro, "[Am]Hello [G]world [C]today")
      chords = Sonx.get_chords(song)
      assert "Am" in chords
      assert "G" in chords
      assert "C" in chords
    end
  end

  describe "serialization" do
    test "serialize and deserialize" do
      song = Sonx.parse!(:chord_pro, "{title: Test}\n[Am]Hello")
      map = Sonx.serialize(song)
      {:ok, restored} = Sonx.deserialize(map)
      assert Sonx.title(restored) == "Test"
    end

    test "to_json and from_json" do
      song = Sonx.parse!(:chord_pro, "{title: Test}\n[Am]Hello")
      json = Sonx.to_json(song)
      {:ok, restored} = Sonx.from_json(json)
      assert Sonx.title(restored) == "Test"
    end
  end

  describe "end-to-end workflow" do
    test "parse UG → transpose → format as ChordPro" do
      ug_input = "[Verse]\nC       G\nHello   world"
      {:ok, song} = Sonx.parse(:ultimate_guitar, ug_input)
      transposed = Sonx.transpose(song, 2)
      output = Sonx.format(:chord_pro, transposed)

      assert output =~ "[D]"
      assert output =~ "[A]"
      assert output =~ "Hello"
    end

    test "parse ChordPro → change key → format as text" do
      {:ok, song} = Sonx.parse(:chord_pro, "{key: C}\n[C]Hello [Am]world [F]today [G]!")
      changed = Sonx.change_key(song, "G")
      text = Sonx.format(:text, changed)

      assert text =~ "G"
      assert text =~ "Em"
      assert text =~ "Hello"
    end

    test "parse → serialize → deserialize → format preserves content" do
      {:ok, song1} = Sonx.parse(:chord_pro, "{title: Test}\n[Am]Hello [G]world")
      json = Sonx.to_json(song1)
      {:ok, song2} = Sonx.from_json(json)
      output = Sonx.format(:chord_pro, song2)

      assert output =~ "{title: Test}"
      assert output =~ "[Am]Hello"
      assert output =~ "[G]world"
    end
  end
end

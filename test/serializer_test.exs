defmodule Sonx.SerializerTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{Metadata, Song}
  alias Sonx.Parser.ChordProParser
  alias Sonx.Serializer

  describe "serialize/1" do
    test "serializes empty song" do
      {:ok, song} = ChordProParser.parse("")
      map = Serializer.serialize(song)
      assert map["type"] == "song"
      assert is_list(map["lines"])
    end

    test "serializes song with metadata" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{key: C}")
      map = Serializer.serialize(song)

      assert map["type"] == "song"
      assert [_, _ | _] = map["lines"]

      tag_items =
        map["lines"]
        |> Enum.flat_map(&Map.get(&1, "items", []))
        |> Enum.filter(&(&1["type"] == "tag"))

      names = Enum.map(tag_items, & &1["name"])
      assert "title" in names
      assert "key" in names
    end

    test "serializes chord-lyrics pairs" do
      {:ok, song} = ChordProParser.parse("[Am]Hello [G]world")
      map = Serializer.serialize(song)

      pairs =
        map["lines"]
        |> Enum.flat_map(&Map.get(&1, "items", []))
        |> Enum.filter(&(&1["type"] == "chord_lyrics_pair"))

      assert [_, _ | _] = pairs
      chords = Enum.map(pairs, & &1["chords"])
      assert "Am" in chords
      assert "G" in chords
    end

    test "serializes ternary expressions" do
      {:ok, song} = ChordProParser.parse("%{title|yes|no}")
      map = Serializer.serialize(song)

      ternaries =
        map["lines"]
        |> Enum.flat_map(&Map.get(&1, "items", []))
        |> Enum.filter(&(&1["type"] == "ternary"))

      assert [_ | _] = ternaries
      t = hd(ternaries)
      assert t["variable"] == "title"
      refute Enum.empty?(t["true_expression"])
      refute Enum.empty?(t["false_expression"])
    end

    test "serializes section types" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      map = Serializer.serialize(song)

      section_types =
        map["lines"]
        |> Enum.map(& &1["section_type"])
        |> Enum.uniq()

      assert "verse" in section_types
    end
  end

  describe "deserialize/1" do
    test "deserializes serialized song" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n[Am]Hello [G]world")
      map = Serializer.serialize(song)
      {:ok, song2} = Serializer.deserialize(map)

      assert Song.title(song2) == "My Song"
      chords = Song.get_chords(song2)
      assert "Am" in chords
      assert "G" in chords
    end

    test "preserves metadata through serialization round-trip" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{artist: John}\n{key: Am}")
      map = Serializer.serialize(song)
      {:ok, song2} = Serializer.deserialize(map)

      meta = Song.metadata(song2)
      assert Metadata.get_single(meta, "title") == "My Song"
      assert Metadata.get_single(meta, "artist") == "John"
      assert Metadata.get_single(meta, "key") == "Am"
    end

    test "preserves section types through round-trip" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      map = Serializer.serialize(song)
      {:ok, song2} = Serializer.deserialize(map)

      verse_lines = Enum.filter(song2.lines, &(&1.type == :verse))
      assert [_ | _] = verse_lines
    end

    test "returns error for invalid map" do
      assert {:error, _} = Serializer.deserialize(%{"invalid" => true})
    end
  end

  describe "to_json/1 and from_json/1" do
    test "JSON round-trip" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n[Am]Hello [G]world")
      json = Serializer.to_json(song)

      assert is_binary(json)
      assert String.contains?(json, "My Song")

      {:ok, song2} = Serializer.from_json(json)
      assert Song.title(song2) == "My Song"
      assert Song.get_chords(song2) == Song.get_chords(song)
    end

    test "from_json returns error for invalid JSON" do
      assert {:error, _} = Serializer.from_json("not json")
    end
  end

  describe "full round-trip: parse → serialize → deserialize → format" do
    test "ChordPro round-trip through JSON" do
      input = "{title: Test}\n{key: C}\n{start_of_verse}\n[Am]Hello [G]world\n{end_of_verse}"
      {:ok, song1} = ChordProParser.parse(input)

      json = Serializer.to_json(song1)
      {:ok, song2} = Serializer.from_json(json)

      # Verify structural equivalence
      assert Song.title(song1) == Song.title(song2)
      assert Song.key(song1) == Song.key(song2)
      assert Song.get_chords(song1) == Song.get_chords(song2)
      assert length(song1.lines) == length(song2.lines)
    end
  end
end

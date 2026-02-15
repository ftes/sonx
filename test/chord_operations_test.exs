defmodule Sonx.ChordOperationsTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{Metadata, Song}
  alias Sonx.Formatter.ChordProFormatter
  alias Sonx.Parser.ChordProParser

  describe "transpose/3" do
    test "transposes song up by 2 semitones" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [G]world [Am]today")
      transposed = Song.transpose(song, 2)

      assert Song.key(transposed) == "D"
      chords = Song.get_chords(transposed)
      assert "D" in chords
      assert "A" in chords
      assert "Bm" in chords
    end

    test "transposes song down by 3 semitones" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [Am]world")
      transposed = Song.transpose(song, -3)

      assert Song.key(transposed) == "A"
      chords = Song.get_chords(transposed)
      assert "A" in chords
    end

    test "transpose by 0 is identity" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [G]world")
      transposed = Song.transpose(song, 0)

      assert Song.key(transposed) == "C"
      assert Song.get_chords(transposed) == Song.get_chords(song)
    end

    test "transpose by 12 returns to same key" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [Am]world")
      transposed = Song.transpose(song, 12)

      assert Song.key(transposed) == "C"
    end

    test "preserves lyrics during transposition" do
      {:ok, song} = ChordProParser.parse("[C]Hello world")
      transposed = Song.transpose(song, 5)
      output = ChordProFormatter.format(transposed)
      assert output =~ "Hello world"
    end
  end

  describe "change_key/2" do
    test "changes key from C to G" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [Am]world [F]today [G]now")
      changed = Song.change_key(song, "G")

      assert Song.key(changed) == "G"
      chords = Song.get_chords(changed)
      assert "G" in chords
      assert "Em" in chords
      assert "C" in chords
      assert "D" in chords
    end

    test "raises when no key is set" do
      {:ok, song} = ChordProParser.parse("[C]Hello [Am]world")

      assert_raise RuntimeError, ~r/original key is unknown/, fn ->
        Song.change_key(song, "G")
      end
    end
  end

  describe "use_accidental/2" do
    test "switches to flat accidentals" do
      {:ok, song} = ChordProParser.parse("[C#]Hello [F#]world")
      flatted = Song.use_accidental(song, :flat)
      chords = Song.get_chords(flatted)
      # C# -> Db, F# -> Gb
      assert "Db" in chords
      assert "Gb" in chords
    end

    test "switches to sharp accidentals" do
      {:ok, song} = ChordProParser.parse("[Db]Hello [Gb]world")
      sharped = Song.use_accidental(song, :sharp)
      chords = Song.get_chords(sharped)
      assert "C#" in chords
      assert "F#" in chords
    end
  end

  describe "set_key/2" do
    test "sets key on song without key" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      updated = Song.set_key(song, "Am")

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "key") == "Am"
    end

    test "changes existing key" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello")
      updated = Song.set_key(song, "G")

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "key") == "G"
    end
  end

  describe "set_capo/2" do
    test "sets capo" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello")
      updated = Song.set_capo(song, 3)

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "capo") == "3"
    end

    test "removes capo with nil" do
      {:ok, song} = ChordProParser.parse("{key: C}\n{capo: 3}\n[C]Hello")
      updated = Song.set_capo(song, nil)

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "capo") == nil
    end
  end

  describe "change_metadata/3" do
    test "changes existing metadata" do
      {:ok, song} = ChordProParser.parse("{title: Old Title}\n[C]Hello")
      updated = Song.change_metadata(song, "title", "New Title")

      assert Song.title(updated) == "New Title"
    end

    test "adds new metadata" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      updated = Song.change_metadata(song, "artist", "John Doe")

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "artist") == "John Doe"
    end

    test "removes metadata with nil" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n[C]Hello")
      updated = Song.change_metadata(song, "title", nil)

      assert Song.title(updated) == nil
    end
  end

  describe "combined operations" do
    test "transpose then format" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [G]world")
      transposed = Song.transpose(song, 5)
      output = ChordProFormatter.format(transposed)

      assert output =~ "[F]Hello"
      assert output =~ "[C]world"
      assert output =~ "{key: F}"
    end

    test "change key then serialize round-trip" do
      {:ok, song} = ChordProParser.parse("{key: C}\n[C]Hello [Am]world")
      changed = Song.change_key(song, "G")

      json = Sonx.Serializer.to_json(changed)
      {:ok, restored} = Sonx.Serializer.from_json(json)

      assert Song.key(restored) == "G"
      assert Song.get_chords(restored) == Song.get_chords(changed)
    end
  end
end

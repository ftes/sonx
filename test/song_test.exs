defmodule Sonx.ChordSheet.SongTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Line,
    Metadata,
    Song,
    Tag
  }

  defp sample_song do
    Song.new(
      lines: [
        Line.new(items: [Tag.new("title", "My Song")]),
        Line.new(items: [Tag.new("key", "C")]),
        Line.new(),
        Line.new(
          type: :verse,
          items: [
            ChordLyricsPair.new("Am", "Hello "),
            ChordLyricsPair.new("C", "world")
          ]
        ),
        Line.new(
          type: :verse,
          items: [
            ChordLyricsPair.new("F", "Second "),
            ChordLyricsPair.new("G", "line")
          ]
        )
      ]
    )
  end

  describe "metadata/1" do
    test "extracts metadata from tags" do
      song = sample_song()
      meta = Song.metadata(song)

      assert Metadata.get_single(meta, "title") == "My Song"
      assert Metadata.get_single(meta, "key") == "C"
    end
  end

  describe "title/1 and key/1" do
    test "returns title" do
      assert Song.title(sample_song()) == "My Song"
    end

    test "returns key" do
      assert Song.key(sample_song()) == "C"
    end
  end

  describe "paragraphs/1" do
    test "groups lines into paragraphs" do
      song = sample_song()
      paragraphs = Song.paragraphs(song)
      # Empty line creates paragraph boundary
      assert length(paragraphs) >= 2
    end
  end

  describe "body_lines/1" do
    test "skips leading non-renderable lines" do
      song = sample_song()
      body = Song.body_lines(song)

      # Should skip metadata-only lines
      assert length(body) < length(song.lines)
    end
  end

  describe "get_chords/1" do
    test "returns unique chords" do
      song = sample_song()
      chords = Song.get_chords(song)

      assert "Am" in chords
      assert "C" in chords
      assert "F" in chords
      assert "G" in chords
    end
  end

  describe "map_items/2" do
    test "transforms items" do
      song = sample_song()

      new_song =
        Song.map_items(song, fn
          %ChordLyricsPair{lyrics: lyrics} = pair ->
            %{pair | lyrics: String.upcase(lyrics)}

          item ->
            item
        end)

      verse_line = Enum.at(new_song.lines, 3)
      first_pair = Enum.at(verse_line.items, 0)
      assert first_pair.lyrics == "HELLO "
    end
  end

  describe "clone/1" do
    test "returns a structurally equal copy" do
      song = sample_song()
      cloned = Song.clone(song)

      assert Song.title(cloned) == Song.title(song)
      assert length(cloned.lines) == length(song.lines)
    end

    test "modifications to clone do not affect original" do
      song = sample_song()
      cloned = Song.clone(song)

      modified = Song.change_metadata(cloned, "title", "Modified")
      assert Song.title(modified) == "Modified"
      assert Song.title(song) == "My Song"
    end
  end

  describe "change_metadata/3" do
    test "updates existing metadata" do
      song = sample_song()
      updated = Song.change_metadata(song, "title", "New Title")

      assert Song.title(updated) == "New Title"
    end

    test "inserts new metadata" do
      song = sample_song()
      updated = Song.change_metadata(song, "artist", "John Doe")

      meta = Song.metadata(updated)
      assert Metadata.get_single(meta, "artist") == "John Doe"
    end
  end
end

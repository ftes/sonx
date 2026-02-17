defmodule Sonx.Parser.LatexSongsParserTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.{ChordLyricsPair, Song, Tag}
  alias Sonx.ChordSheet.Metadata
  alias Sonx.Parser.LatexSongsParser

  describe "header parsing" do
    test "parses title" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{My Song}[by={}]\n\\endsong")
      assert Song.title(song) == "My Song"
    end

    test "parses title and subtitle" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{My Song \\\\ Sub}[by={}]\n\\endsong")
      assert Song.title(song) == "My Song"
      assert Song.subtitle(song) == "Sub"
    end

    test "parses title and artist" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{My Song}[by={Artist}]\n\\endsong")
      assert Song.title(song) == "My Song"

      metadata = Song.metadata(song)
      assert Metadata.get(metadata, "artist") == "Artist"
    end

    test "parses all header fields" do
      input = "\\beginsong{Title \\\\ Subtitle}[by={The Artist}]\n\\endsong"
      {:ok, song} = LatexSongsParser.parse(input)
      assert Song.title(song) == "Title"
      assert Song.subtitle(song) == "Subtitle"

      metadata = Song.metadata(song)
      assert Metadata.get(metadata, "artist") == "The Artist"
    end

    test "handles empty artist" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{Title}[by={}]\n\\endsong")
      assert Song.title(song) == "Title"
    end

    test "handles missing by clause" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{Title}\n\\endsong")
      assert Song.title(song) == "Title"
    end

    test "unescapes special chars in title" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{Tom \\& Jerry}[by={}]\n\\endsong")
      assert Song.title(song) == "Tom & Jerry"
    end

    test "unescapes special chars in artist" do
      {:ok, song} = LatexSongsParser.parse("\\beginsong{Song}[by={R\\&B Artist}]\n\\endsong")

      metadata = Song.metadata(song)
      assert Metadata.get(metadata, "artist") == "R&B Artist"
    end
  end

  describe "sections" do
    test "parses verse section" do
      input = "\\beginsong{T}[by={}]\n\\beginverse\n\\[Am]Hello\n\\endverse\n\\endsong"
      {:ok, song} = LatexSongsParser.parse(input)

      assert find_tag(song, "start_of_verse") != nil
      assert find_tag(song, "end_of_verse") != nil
    end

    test "parses chorus section" do
      input = "\\beginsong{T}[by={}]\n\\beginchorus\n\\[Am]Hello\n\\endchorus\n\\endsong"
      {:ok, song} = LatexSongsParser.parse(input)

      assert find_tag(song, "start_of_chorus") != nil
      assert find_tag(song, "end_of_chorus") != nil
    end

    test "parses unnumbered verse (beginverse*)" do
      input = "\\beginsong{T}[by={}]\n\\beginverse*\n\\[Am]Hello\n\\endverse\n\\endsong"
      {:ok, song} = LatexSongsParser.parse(input)

      assert find_tag(song, "start_of_verse") != nil
    end

    test "parses multiple sections" do
      input = """
      \\beginsong{T}[by={}]
      \\beginverse
      \\[C]Hello
      \\endverse
      \\beginchorus
      \\[Am]Chorus
      \\endchorus
      \\endsong
      """

      {:ok, song} = LatexSongsParser.parse(input)

      assert find_tag(song, "start_of_verse") != nil
      assert find_tag(song, "end_of_verse") != nil
      assert find_tag(song, "start_of_chorus") != nil
      assert find_tag(song, "end_of_chorus") != nil
    end
  end

  describe "inline chords" do
    test "parses single chord with lyrics" do
      {:ok, song} = LatexSongsParser.parse("\\[Am]Hello world")

      pair = find_chord_pair(song)
      assert pair.chords == "Am"
      assert pair.lyrics == "Hello world"
    end

    test "parses multiple chords on one line" do
      {:ok, song} = LatexSongsParser.parse("\\[Am]Hello \\[G]world")

      chords = Song.get_chords(song)
      assert chords == ["Am", "G"]
    end

    test "parses chord-only content" do
      {:ok, song} = LatexSongsParser.parse("\\[F]\\[C]\\[Dm]")

      chords = Song.get_chords(song)
      assert chords == ["F", "C", "Dm"]
    end

    test "parses lyrics before first chord" do
      {:ok, song} = LatexSongsParser.parse("Hello \\[Am]world")

      line = find_content_line(song)
      [first | _] = line.items
      assert %ChordLyricsPair{chords: "", lyrics: "Hello "} = first
    end

    test "parses complex chord names" do
      {:ok, song} = LatexSongsParser.parse("\\[C#m7]Hello \\[Bb/F]world")

      chords = Song.get_chords(song)
      assert "C#m7" in chords
      assert "Bb/F" in chords
    end

    test "handles mid-word chords" do
      {:ok, song} = LatexSongsParser.parse("King\\[F]dom")

      line = find_content_line(song)
      pairs = Enum.filter(line.items, &match?(%ChordLyricsPair{}, &1))
      [first, second] = pairs
      assert first.chords == ""
      assert first.lyrics == "King"
      assert second.chords == "F"
      assert second.lyrics == "dom"
    end

    test "parses chords with space after" do
      {:ok, song} = LatexSongsParser.parse("\\[Am] \\[C] \\[D]")

      chords = Song.get_chords(song)
      assert chords == ["Am", "C", "D"]
    end
  end

  describe "capo" do
    test "parses capo tag" do
      {:ok, song} = LatexSongsParser.parse("\\capo{3}")

      tag = find_tag(song, "capo")
      assert tag != nil
      assert tag.value == "3"
    end
  end

  describe "comments" do
    test "parses textcomment" do
      {:ok, song} = LatexSongsParser.parse("\\textcomment{Hello}")

      tag = find_tag(song, "comment")
      assert tag != nil
      assert tag.value == "Hello"
    end

    test "parses textnote" do
      {:ok, song} = LatexSongsParser.parse("\\textnote{A note}")

      tag = find_tag(song, "comment")
      assert tag != nil
      assert tag.value == "A note"
    end

    test "parses musicnote" do
      {:ok, song} = LatexSongsParser.parse("\\musicnote{Play softly}")

      tag = find_tag(song, "comment")
      assert tag != nil
      assert tag.value == "Play softly"
    end

    test "unescapes special chars in comment" do
      {:ok, song} = LatexSongsParser.parse("\\textcomment{100\\% done}")

      tag = find_tag(song, "comment")
      assert tag.value == "100% done"
    end
  end

  describe "echo" do
    test "parses echo content as chord/lyrics" do
      {:ok, song} = LatexSongsParser.parse("\\echo{\\[Am]echo text}")

      chords = Song.get_chords(song)
      assert "Am" in chords
    end

    test "parses echo without chords" do
      {:ok, song} = LatexSongsParser.parse("\\echo{just text}")

      line = find_content_line(song)
      assert line != nil
    end
  end

  describe "LaTeX unescaping" do
    test "unescapes ampersand" do
      {:ok, song} = LatexSongsParser.parse("\\[C]Tom \\& Jerry")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "Tom & Jerry"
    end

    test "unescapes percent" do
      {:ok, song} = LatexSongsParser.parse("\\[C]100\\%")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "100%"
    end

    test "unescapes dollar" do
      {:ok, song} = LatexSongsParser.parse("\\[C]Cost \\$5")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "Cost $5"
    end

    test "unescapes hash" do
      {:ok, song} = LatexSongsParser.parse("\\[C]item \\#1")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "item #1"
    end

    test "unescapes underscore" do
      {:ok, song} = LatexSongsParser.parse("\\[C]some\\_text")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "some_text"
    end

    test "unescapes braces" do
      {:ok, song} = LatexSongsParser.parse("\\[C]a\\{b\\}c")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "a{b}c"
    end

    test "unescapes backslash" do
      {:ok, song} = LatexSongsParser.parse("\\[C]a\\textbackslash{}b")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "a\\b"
    end

    test "unescapes tilde" do
      {:ok, song} = LatexSongsParser.parse("\\[C]a\\textasciitilde{}b")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "a~b"
    end

    test "unescapes caret" do
      {:ok, song} = LatexSongsParser.parse("\\[C]a\\textasciicircum{}b")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "a^b"
    end

    test "handles multiple escapes" do
      {:ok, song} = LatexSongsParser.parse("\\[C]100\\% pure \\& good")

      pair = find_chord_pair(song)
      assert pair.lyrics =~ "100% pure & good"
    end
  end

  describe "skipped commands" do
    test "skips transpose without error" do
      {:ok, _song} = LatexSongsParser.parse("\\transpose{2}\n\\[Am]Hello")
    end

    test "skips memorize without error" do
      {:ok, _song} = LatexSongsParser.parse("\\memorize\n\\[Am]Hello")
    end

    test "skips replay without error" do
      {:ok, _song} = LatexSongsParser.parse("\\replay\n\\[Am]Hello")
    end

    test "skips rep without error" do
      {:ok, _song} = LatexSongsParser.parse("\\rep{3}\n\\[Am]Hello")
    end

    test "skips lrep and rrep without error" do
      {:ok, _song} = LatexSongsParser.parse("\\lrep\n\\[Am]Hello\n\\rrep")
    end

    test "skips gtab without error" do
      {:ok, _song} = LatexSongsParser.parse("\\gtab{A}{X02220}")
    end

    test "skips LaTeX comments" do
      {:ok, song} = LatexSongsParser.parse("% this is a comment\n\\[Am]Hello")

      chords = Song.get_chords(song)
      assert chords == ["Am"]
    end

    test "skips scripture block" do
      input = """
      \\beginscripture{John 3:16}
      For God so loved the world
      \\endscripture
      \\[Am]Hello
      """

      {:ok, song} = LatexSongsParser.parse(input)
      chords = Song.get_chords(song)
      assert chords == ["Am"]
    end
  end

  describe "empty input" do
    test "parses empty string" do
      {:ok, song} = LatexSongsParser.parse("")
      assert Enum.all?(song.lines, fn line -> line.items == [] end)
    end

    test "parses whitespace-only" do
      {:ok, song} = LatexSongsParser.parse("   \n   \n   ")
      assert Enum.all?(song.lines, fn line -> line.items == [] end)
    end
  end

  describe "paragraph breaks" do
    test "empty lines create paragraph breaks" do
      input = "\\[Am]First\n\n\\[G]Second"
      {:ok, song} = LatexSongsParser.parse(input)

      content_lines =
        Enum.filter(song.lines, fn line ->
          Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
        end)

      assert length(content_lines) == 2
    end
  end

  describe "fixture" do
    test "parses simple.tex fixture" do
      input = File.read!("test/support/fixtures/latex_songs/simple.tex")
      {:ok, song} = LatexSongsParser.parse(input)

      assert Song.title(song) == "Let It Be"
      assert Song.subtitle(song) == "Beatles"

      chords = Song.get_chords(song)
      assert "C" in chords
      assert "G" in chords
      assert "Am" in chords
      assert "F" in chords

      assert find_tag(song, "start_of_verse") != nil
      assert find_tag(song, "start_of_chorus") != nil
    end

    test "parses complex.tex fixture" do
      input = File.read!("test/support/fixtures/latex_songs/complex.tex")
      {:ok, song} = LatexSongsParser.parse(input)

      assert Song.title(song) == "Firm Foundation"

      tag = find_tag(song, "capo")
      assert tag != nil
      assert tag.value == "3"

      comment = find_tag(song, "comment")
      assert comment != nil
      assert comment.value == "Repeat Chorus 2"
    end

    test "parses edge_cases.tex fixture" do
      input = File.read!("test/support/fixtures/latex_songs/edge_cases.tex")
      {:ok, song} = LatexSongsParser.parse(input)

      assert Song.title(song) == "Edge Cases"

      chords = Song.get_chords(song)
      assert "D/F#" in chords
      assert "Am7" in chords
      assert "D7sus4" in chords
    end

    test "parses kingdom.tex fixture" do
      input = File.read!("test/support/fixtures/latex_songs/kingdom.tex")
      {:ok, song} = LatexSongsParser.parse(input)

      assert Song.title(song) == "Kingdom"

      chords = Song.get_chords(song)
      assert "Gm7/C" in chords
      assert "Dm7" in chords
    end
  end

  # --- Helpers ---

  defp find_tag(song, tag_name) do
    Enum.find_value(song.lines, fn line ->
      Enum.find(line.items, fn
        %Tag{name: ^tag_name} -> true
        _ -> false
      end)
    end)
  end

  defp find_chord_pair(song) do
    Enum.find_value(song.lines, fn line ->
      Enum.find(line.items, fn
        %ChordLyricsPair{chords: c} when c != "" -> true
        _ -> false
      end)
    end)
  end

  defp find_content_line(song) do
    Enum.find(song.lines, fn line ->
      Enum.any?(line.items, &match?(%ChordLyricsPair{}, &1))
    end)
  end
end

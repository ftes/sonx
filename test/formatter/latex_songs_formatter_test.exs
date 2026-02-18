defmodule Sonx.Formatter.LatexSongsFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.LatexSongsFormatter
  alias Sonx.Parser.ChordProParser
  alias Sonx.Parser.TypstParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\beginsong"
      assert result =~ "\\endsong"
    end

    test "formats song with title" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\beginsong{My Song}"
    end

    test "formats song with title and subtitle" do
      input = "{title: My Song}\n{subtitle: The Subtitle}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\beginsong{My Song \\\\ The Subtitle}"
    end

    test "formats song with artist" do
      input = "{title: My Song}\n{artist: John Doe}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)
      assert result =~ "[by={John Doe}]"
    end

    test "formats header with all metadata" do
      input = "{title: My Song}\n{subtitle: Sub}\n{artist: Artist}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\beginsong{My Song \\\\ Sub}[by={Artist}]"
    end
  end

  describe "inline chords" do
    test "formats chords inline with lyrics" do
      {:ok, song} = ChordProParser.parse("[Am]Hello [G]world")
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\[Am]Hello \\[G]world"
    end

    test "formats chord-only content" do
      {:ok, song} = ChordProParser.parse("[F][C][Dm]")
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\[F]\\[C]\\[Dm]"
    end

    test "formats lyrics without chords" do
      {:ok, song} = ChordProParser.parse("Just some words")
      result = LatexSongsFormatter.format(song)
      assert result =~ "Just some words"
    end
  end

  describe "sections" do
    test "formats verse section" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginverse"
      assert result =~ "\\[C]Hello"
      assert result =~ "\\endverse"
    end

    test "formats chorus section" do
      input = "{start_of_chorus}\n[Am]Let it be\n{end_of_chorus}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginchorus"
      assert result =~ "\\[Am]Let it be"
      assert result =~ "\\endchorus"
    end

    test "formats multiple sections" do
      input = """
      {start_of_verse}
      [C]Hello [G]world
      {end_of_verse}
      {start_of_chorus}
      [Am]Let it [F]be
      {end_of_chorus}
      """

      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginverse"
      assert result =~ "\\endverse"
      assert result =~ "\\beginchorus"
      assert result =~ "\\endchorus"
    end
  end

  describe "comments and capo" do
    test "formats comment tag" do
      input = "{comment: This is a comment}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\textcomment{This is a comment}"
    end

    test "formats capo tag" do
      input = "{capo: 3}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)
      assert result =~ "\\capo{3}"
    end
  end

  describe "LaTeX escaping" do
    test "escapes special characters in lyrics" do
      {:ok, song} = ChordProParser.parse("[C]100% pure & good")
      result = LatexSongsFormatter.format(song)
      assert result =~ "100\\% pure \\& good"
    end

    test "escapes dollar sign" do
      {:ok, song} = ChordProParser.parse("[C]Cost $5")
      result = LatexSongsFormatter.format(song)
      assert result =~ "Cost \\$5"
    end

    test "escapes underscore" do
      {:ok, song} = ChordProParser.parse("[C]some_text")
      result = LatexSongsFormatter.format(song)
      assert result =~ "some\\_text"
    end
  end

  describe "structure" do
    test "wraps output in beginsong/endsong" do
      {:ok, song} = ChordProParser.parse("{title: Test}\n[Am]Hello")
      result = LatexSongsFormatter.format(song)

      lines = String.split(result, "\n")
      assert List.first(lines) =~ "\\beginsong"
      assert List.last(lines) == "\\endsong"
    end

    test "skips header tags in body" do
      input = "{title: My Song}\n{artist: Artist}\n[Am]Hello"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      # title and artist should only appear in \beginsong header, not repeated
      occurrences =
        result
        |> String.split("My Song")
        |> length()

      # "My Song" should appear once (in \beginsong)
      assert occurrences == 2
    end
  end

  describe "auto-closing sections" do
    test "auto-closes verse when no explicit end tag" do
      input = "{start_of_verse}\n[C]Hello\n{start_of_chorus}\n[Am]World\n{end_of_chorus}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginverse\n\\[C]Hello\n\\endverse\n\\beginchorus"
    end

    test "auto-closes section at end of song" do
      input = "{start_of_verse}\n[C]Hello"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginverse\n\\[C]Hello\n\\endverse\n\\endsong"
    end

    test "does not double-close when explicit end tag exists" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      count = result |> String.split("\\endverse") |> length()
      # "\\endverse" appears exactly once → splits into 2 parts
      assert count == 2
    end

    test "auto-closes chorus at end of song" do
      input = "{start_of_chorus}\n[Am]Let it be"
      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginchorus\n\\[Am]Let it be\n\\endchorus\n\\endsong"
    end

    test "works with typst-parsed input (no end tags)" do
      input = """
      = Let It Be

      === Verse

      [C] Hello [G] world

      === Chorus

      [Am] Let it [F] be
      """

      {:ok, song} = TypstParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginverse"
      assert result =~ "\\endverse"
      assert result =~ "\\beginchorus"
      assert result =~ "\\endchorus"
      # endverse must come before beginchorus
      endverse_pos = :binary.match(result, "\\endverse") |> elem(0)
      beginchorus_pos = :binary.match(result, "\\beginchorus") |> elem(0)
      assert endverse_pos < beginchorus_pos
    end
  end

  describe "chord_diagrams option" do
    test "inserts gtab lines between header and body" do
      {:ok, song} = ChordProParser.parse("[Am]Hello [C]world")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Am}{X02210}"
      assert result =~ "\\gtab{C}{X32010}"

      # gtab lines should appear before song body
      [before_body, _] = String.split(result, "\\[Am]", parts: 2)
      assert before_body =~ "\\gtab{Am}"
      assert before_body =~ "\\gtab{C}"
    end

    test "handles slash chords with known voicings" do
      {:ok, song} = ChordProParser.parse("[C/G]Hello")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{C/G}{332010}"
    end

    test "handles enharmonic equivalents" do
      {:ok, song} = ChordProParser.parse("[Bb]Hello [F#m]world")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Bb}{X(13331)}"
      assert result =~ "\\gtab{F#m}{(244222)}"
    end

    test "skips chords not in database" do
      {:ok, song} = ChordProParser.parse("[Cmaj9]Hello")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      refute result =~ "\\gtab"
    end

    test "barre notation for E-shape major barres" do
      {:ok, song} = ChordProParser.parse("[F]1 [F#]2 [Ab]3")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{F}{(133211)}"
      assert result =~ "\\gtab{F#}{(244322)}"
      assert result =~ "\\gtab{Ab}{(466544)}"
    end

    test "barre notation for A-shape major barres" do
      {:ok, song} = ChordProParser.parse("[Db]1 [Bb]2 [B]3")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Db}{X(46664)}"
      assert result =~ "\\gtab{Bb}{X(13331)}"
      assert result =~ "\\gtab{B}{X(24442)}"
    end

    test "barre notation for Em-shape minor barres" do
      {:ok, song} = ChordProParser.parse("[Fm]1 [F#m]2 [Gm]3 [Abm]4")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Fm}{(133111)}"
      assert result =~ "\\gtab{F#m}{(244222)}"
      assert result =~ "\\gtab{Gm}{(355333)}"
      assert result =~ "\\gtab{Abm}{(466444)}"
    end

    test "barre notation for Am-shape minor barres" do
      {:ok, song} = ChordProParser.parse("[Cm]1 [C#m]2 [Bbm]3 [Bm]4")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Cm}{X(35543)}"
      assert result =~ "\\gtab{C#m}{X(46654)}"
      assert result =~ "\\gtab{Bbm}{X(13321)}"
      assert result =~ "\\gtab{Bm}{X(24432)}"
    end

    test "barre notation for dominant 7th barres" do
      {:ok, song} = ChordProParser.parse("[F7]1 [F#7]2 [Ab7]3 [Db7]4 [Bb7]5")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      # E-shape dom7
      assert result =~ "\\gtab{F7}{(131211)}"
      assert result =~ "\\gtab{F#7}{(242322)}"
      assert result =~ "\\gtab{Ab7}{(464544)}"
      # A-shape dom7
      assert result =~ "\\gtab{Db7}{X(46464)}"
      assert result =~ "\\gtab{Bb7}{X(13131)}"
    end

    test "barre notation for minor 7th barres" do
      {:ok, song} = ChordProParser.parse("[Fm7]1 [F#m7]2 [Gm7]3 [Cm7]4 [Bm7]5")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      # Em7-shape
      assert result =~ "\\gtab{Fm7}{(131111)}"
      assert result =~ "\\gtab{F#m7}{(242222)}"
      assert result =~ "\\gtab{Gm7}{(353333)}"
      # Am7-shape
      assert result =~ "\\gtab{Cm7}{X(35343)}"
      assert result =~ "\\gtab{Bm7}{X(24232)}"
    end

    test "no barre notation for open major chords" do
      {:ok, song} = ChordProParser.parse("[C]1 [D]2 [E]3 [G]4 [A]5")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{C}{X32010}"
      assert result =~ "\\gtab{D}{XX0232}"
      assert result =~ "\\gtab{E}{022100}"
      assert result =~ "\\gtab{G}{320003}"
      assert result =~ "\\gtab{A}{X02220}"
    end

    test "no barre notation for open minor chords" do
      {:ok, song} = ChordProParser.parse("[Dm]1 [Em]2 [Am]3")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Dm}{XX0231}"
      assert result =~ "\\gtab{Em}{022000}"
      assert result =~ "\\gtab{Am}{X02210}"
    end

    test "no barre notation for open 7th chords" do
      {:ok, song} = ChordProParser.parse("[C7]1 [D7]2 [E7]3 [G7]4 [A7]5 [B7]6")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{C7}{X32310}"
      assert result =~ "\\gtab{D7}{XX0212}"
      assert result =~ "\\gtab{E7}{020100}"
      assert result =~ "\\gtab{G7}{320001}"
      assert result =~ "\\gtab{A7}{X02020}"
      assert result =~ "\\gtab{B7}{X21202}"
    end

    test "no barre notation for maj7, sus2, sus4 chords" do
      {:ok, song} = ChordProParser.parse("[Cmaj7]1 [Dmaj7]2 [Gmaj7]3 [Dsus2]4 [Asus4]5")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Cmaj7}{X32000}"
      assert result =~ "\\gtab{Dmaj7}{XX0222}"
      assert result =~ "\\gtab{Gmaj7}{320002}"
      assert result =~ "\\gtab{Dsus2}{XX0230}"
      assert result =~ "\\gtab{Asus4}{X02230}"
    end

    test "no barre notation for slash chords" do
      {:ok, song} = ChordProParser.parse("[C/G]1 [C/E]2")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{C/G}{332010}"
      assert result =~ "\\gtab{C/E}{032010}"
    end

    test "no barre notation for partial shape chords" do
      {:ok, song} = ChordProParser.parse("[Eb]1 [Ebm]2 [Dm7]3 [Am7]4")
      result = LatexSongsFormatter.format(song, chord_diagrams: true)

      assert result =~ "\\gtab{Eb}{XX1343}"
      assert result =~ "\\gtab{Ebm}{XX1342}"
      assert result =~ "\\gtab{Dm7}{XX0211}"
      assert result =~ "\\gtab{Am7}{X02010}"
    end

    test "does not include gtab by default" do
      {:ok, song} = ChordProParser.parse("[Am]Hello")
      result = LatexSongsFormatter.format(song)

      refute result =~ "\\gtab"
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      input = File.read!("test/support/fixtures/chord_pro/simple.cho")

      {:ok, song} = ChordProParser.parse(input)
      result = LatexSongsFormatter.format(song)

      assert result =~ "\\beginsong{Let It Be"
      assert result =~ "\\endsong"
      assert result =~ "\\beginverse"
      assert result =~ "\\[C]"
    end
  end
end

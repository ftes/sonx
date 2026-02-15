defmodule Sonx.Formatter.HtmlDivFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.HtmlDivFormatter
  alias Sonx.Parser.ChordProParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = HtmlDivFormatter.format(song)
      assert result == ""
    end

    test "formats song with title" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<h1 class=\"title\">My Song</h1>"
    end

    test "formats song with title and subtitle" do
      {:ok, song} = ChordProParser.parse("{title: My Song}\n{subtitle: The Sub}")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<h1 class=\"title\">My Song</h1>"
      assert result =~ "<h2 class=\"subtitle\">The Sub</h2>"
    end
  end

  describe "chord sheet structure" do
    test "wraps body in chord-sheet div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<div class=\"chord-sheet\">"
      assert result =~ "</div>"
    end

    test "wraps paragraph in paragraph div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<div class=\"paragraph\">"
    end

    test "wraps line in row div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<div class=\"row\">"
    end

    test "wraps chord-lyrics pair in column div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<div class=\"column\">"
      assert result =~ "<div class=\"chord\">C</div>"
      assert result =~ "<div class=\"lyrics\">Hello</div>"
    end
  end

  describe "chord-lyrics pairs" do
    test "formats multiple pairs per line" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = HtmlDivFormatter.format(song)

      assert result =~ "<div class=\"chord\">C</div>"
      assert result =~ "<div class=\"chord\">G</div>"
      assert result =~ "<div class=\"lyrics\">Hello </div>"
      assert result =~ "<div class=\"lyrics\">world</div>"
    end

    test "formats empty chords" do
      {:ok, song} = ChordProParser.parse("Just lyrics")
      result = HtmlDivFormatter.format(song)
      assert result =~ "<div class=\"chord\"></div>"
      assert result =~ "<div class=\"lyrics\">Just lyrics</div>"
    end
  end

  describe "sections" do
    test "adds section type to paragraph class" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = HtmlDivFormatter.format(song)
      assert result =~ "class=\"paragraph verse\""
    end

    test "adds chorus type to paragraph class" do
      input = "{start_of_chorus}\n[Am]Let it be\n{end_of_chorus}"
      {:ok, song} = ChordProParser.parse(input)
      result = HtmlDivFormatter.format(song)
      assert result =~ "class=\"paragraph chorus\""
    end

    test "renders section label" do
      input = "{start_of_verse: label=\"Verse 1\"}\n[C]Hello"
      {:ok, song} = ChordProParser.parse(input)
      result = HtmlDivFormatter.format(song)
      assert result =~ "<h3 class=\"label\">Verse 1</h3>"
    end
  end

  describe "comments" do
    test "renders comment tag on a line with other content" do
      # Comments as standalone lines are not renderable in paragraph-based formatters.
      # Comment tags (from {comment: ...} directive) on renderable lines do appear.
      {:ok, song} = ChordProParser.parse("{comment: This is a comment}")
      result = HtmlDivFormatter.format(song)
      assert result =~ "This is a comment"
    end
  end

  describe "HTML escaping" do
    test "escapes special characters in lyrics" do
      {:ok, song} = ChordProParser.parse("[C]Hello <world> & \"friends\"")
      result = HtmlDivFormatter.format(song)
      assert result =~ "&lt;world&gt;"
      assert result =~ "&amp;"
      assert result =~ "&quot;friends&quot;"
    end
  end

  describe "custom CSS classes" do
    test "uses custom CSS classes" do
      {:ok, song} = ChordProParser.parse("[C]Hello")

      result =
        HtmlDivFormatter.format(song, css_classes: %{chord: "my-chord", lyrics: "my-lyrics"})

      assert result =~ "class=\"my-chord\""
      assert result =~ "class=\"my-lyrics\""
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      fixture_path = Path.join([__DIR__, "..", "support", "fixtures", "chord_pro", "simple.cho"])
      input = File.read!(fixture_path)

      {:ok, song} = ChordProParser.parse(input)
      result = HtmlDivFormatter.format(song)

      assert result =~ "<h1 class=\"title\">Let It Be</h1>"
      assert result =~ "class=\"paragraph verse\""
      assert result =~ "class=\"paragraph chorus\""
      assert result =~ "<div class=\"chord\">C</div>"
      assert result =~ "When I find"
    end
  end
end

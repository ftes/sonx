defmodule Sonx.Formatter.HtmlTableFormatterTest do
  use ExUnit.Case, async: true

  alias Sonx.Formatter.HtmlTableFormatter
  alias Sonx.Parser.ChordProParser

  describe "basic formatting" do
    test "formats empty song" do
      {:ok, song} = ChordProParser.parse("")
      result = HtmlTableFormatter.format(song)
      assert result == ""
    end

    test "formats song with title" do
      {:ok, song} = ChordProParser.parse("{title: My Song}")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<h1 class=\"title\">My Song</h1>"
    end
  end

  describe "table structure" do
    test "wraps body in chord-sheet div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<div class=\"chord-sheet\">"
    end

    test "wraps paragraph in paragraph div" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<div class=\"paragraph\">"
    end

    test "uses table for each line" do
      {:ok, song} = ChordProParser.parse("[C]Hello")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<table class=\"row\">"
      assert result =~ "</table>"
    end

    test "creates chord row with td cells" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<td class=\"chord\">C</td>"
      assert result =~ "<td class=\"chord\">G</td>"
    end

    test "creates lyrics row with td cells" do
      {:ok, song} = ChordProParser.parse("[C]Hello [G]world")
      result = HtmlTableFormatter.format(song)
      assert result =~ "<td class=\"lyrics\">Hello </td>"
      assert result =~ "<td class=\"lyrics\">world</td>"
    end
  end

  describe "sections" do
    test "adds section type to paragraph class" do
      input = "{start_of_verse}\n[C]Hello\n{end_of_verse}"
      {:ok, song} = ChordProParser.parse(input)
      result = HtmlTableFormatter.format(song)
      assert result =~ "class=\"paragraph verse\""
    end

    test "renders section label in label-wrapper" do
      input = "{start_of_verse: label=\"Verse 1\"}\n[C]Hello"
      {:ok, song} = ChordProParser.parse(input)
      result = HtmlTableFormatter.format(song)
      assert result =~ "class=\"label-wrapper\""
      assert result =~ "<h3 class=\"label\">Verse 1</h3>"
    end
  end

  describe "HTML escaping" do
    test "escapes special characters" do
      {:ok, song} = ChordProParser.parse("[C]Hello <world>")
      result = HtmlTableFormatter.format(song)
      assert result =~ "&lt;world&gt;"
    end
  end

  describe "custom CSS classes" do
    test "uses custom CSS classes" do
      {:ok, song} = ChordProParser.parse("[C]Hello")

      result =
        HtmlTableFormatter.format(song, css_classes: %{chord: "my-chord", lyrics: "my-lyrics"})

      assert result =~ "class=\"my-chord\""
      assert result =~ "class=\"my-lyrics\""
    end
  end

  describe "fixture" do
    test "formats simple.cho fixture" do
      input = File.read!("test/support/fixtures/chord_pro/simple.cho")

      {:ok, song} = ChordProParser.parse(input)
      result = HtmlTableFormatter.format(song)

      assert result =~ "<h1 class=\"title\">Let It Be</h1>"
      assert result =~ "class=\"paragraph verse\""
      assert result =~ "class=\"paragraph chorus\""
      assert result =~ "<td class=\"chord\">C</td>"
      assert result =~ "When I find"
    end
  end
end

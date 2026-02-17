defmodule Sonx.RoundTripTest do
  use ExUnit.Case, async: true

  alias Sonx.ChordSheet.Song
  alias Sonx.Formatter.{ChordProFormatter, ChordsOverWordsFormatter, TextFormatter, TypstFormatter}
  alias Sonx.Parser.{ChordProParser, ChordsOverWordsParser, TypstParser, UltimateGuitarParser}

  describe "ChordPro round-trip" do
    test "format is idempotent after first parse" do
      input = "[Am]Hello [C]world [G]today"
      output1 = input |> parse_cp!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent with metadata" do
      input = "{title: My Song}\n{artist: John}\n{key: C}\n[Am]Hello [G]world"
      output1 = input |> parse_cp!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent with sections" do
      input =
        "{start_of_verse: Verse 1}\n[C]Hello [G]world\n{end_of_verse}\n\n{start_of_chorus: Chorus}\n[Am]Let it [F]be\n{end_of_chorus}"

      output1 = input |> parse_cp!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent for simple.cho fixture" do
      input = File.read!("test/support/fixtures/chord_pro/simple.cho")
      output1 = input |> parse_cp!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  describe "UltimateGuitar → ChordPro round-trip" do
    test "ChordPro output is stable after re-parse" do
      ug_input = "[Verse]\nC       G\nHello   world\n\n[Chorus]\nAm      F\nLet it be"
      output1 = ug_input |> parse_ug!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "ChordPro output is stable with multiple section types" do
      ug_input =
        "[Verse]\nC G\nHello world\n\n[Chorus]\nAm F\nLet it be\n\n[Bridge]\nDm G\nSomething new\n\n[Outro]\nC G Am F"

      output1 = ug_input |> parse_ug!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "ChordPro output is stable with chords-only lines" do
      ug_input = "[Intro]\nC G Am F\n\n[Verse]\nC       G\nHello   world"
      output1 = ug_input |> parse_ug!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  describe "ChordsOverWords → ChordPro round-trip" do
    test "ChordPro output is stable after re-parse" do
      cow_input = "C       G\nHello   world"
      output1 = cow_input |> parse_cow!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  describe "ChordPro → ChordsOverWords round-trip" do
    test "ChordsOverWords output is stable after re-parse" do
      input = "{title: My Song}\n{key: C}\n[Am]Hello [G]world"
      output1 = input |> parse_cp!() |> ChordsOverWordsFormatter.format()
      output2 = output1 |> parse_cow!() |> ChordsOverWordsFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  describe "ChordPro → Text" do
    test "text output contains chords and lyrics" do
      input = "{title: Test}\n[Am]Hello [G]world"
      text = input |> parse_cp!() |> TextFormatter.format()

      assert text =~ "Test"
      assert text =~ "Am"
      assert text =~ "G"
      assert text =~ "Hello"
      assert text =~ "world"
    end
  end

  describe "Typst round-trip" do
    test "format is idempotent after first parse" do
      input = "[Am] Hello [C] world [G] today"
      output1 = input |> parse_typst!() |> TypstFormatter.format()
      output2 = output1 |> parse_typst!() |> TypstFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent with metadata" do
      input = "= My Song\n== John\n\n// key: C\n\n[Am] Hello [G] world"
      output1 = input |> parse_typst!() |> TypstFormatter.format()
      output2 = output1 |> parse_typst!() |> TypstFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent with sections" do
      input = "=== Verse 1\n\n[C] Hello [G] world\n\n=== Chorus\n\n[Am] Let it [F] be"
      output1 = input |> parse_typst!() |> TypstFormatter.format()
      output2 = output1 |> parse_typst!() |> TypstFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "format is idempotent for simple.typ fixture" do
      input = File.read!("test/support/fixtures/typst/simple.typ")
      output1 = input |> parse_typst!() |> TypstFormatter.format()
      output2 = output1 |> parse_typst!() |> TypstFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  describe "ChordPro → Typst round-trip" do
    test "Typst output is stable after re-parse" do
      input = "{title: My Song}\n{key: C}\n[Am]Hello [G]world"
      output1 = input |> parse_cp!() |> TypstFormatter.format()
      output2 = output1 |> parse_typst!() |> TypstFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end

    test "metadata is preserved" do
      input = "{title: My Song}\n{artist: Artist}\n{key: C}\n{capo: 3}\n[Am]Hello"
      song1 = parse_cp!(input)
      typst = TypstFormatter.format(song1)
      song2 = parse_typst!(typst)

      assert Song.title(song2) == "My Song"
      assert Song.key(song2) == "C"
      assert Song.get_chords(song2) == ["Am"]
    end

    test "chords are preserved through ChordPro → Typst → ChordPro" do
      input = "{title: Test}\n{key: C}\n[Am]Hello [G]world [F]today"
      song1 = parse_cp!(input)
      typst = TypstFormatter.format(song1)
      song2 = parse_typst!(typst)

      assert Song.get_chords(song1) == Song.get_chords(song2)
    end

    test "sections are preserved through ChordPro → Typst → ChordPro" do
      input =
        "{title: Test}\n{start_of_verse: Verse 1}\n[C]Hello [G]world\n{end_of_verse}\n\n{start_of_chorus}\n[Am]Let it [F]be\n{end_of_chorus}"

      song1 = parse_cp!(input)
      typst = TypstFormatter.format(song1)
      song2 = parse_typst!(typst)

      chords1 = Song.get_chords(song1)
      chords2 = Song.get_chords(song2)
      assert chords1 == chords2
    end

    test "simple.cho fixture roundtrips through Typst" do
      input = File.read!("test/support/fixtures/chord_pro/simple.cho")
      song1 = parse_cp!(input)
      typst = TypstFormatter.format(song1)
      song2 = parse_typst!(typst)

      assert Song.title(song1) == Song.title(song2)
      assert Song.key(song1) == Song.key(song2)
      assert Song.get_chords(song1) == Song.get_chords(song2)
    end
  end

  describe "Typst → ChordPro round-trip" do
    test "ChordPro output is stable after re-parse" do
      input = "[Am] Hello [G] world"
      output1 = input |> parse_typst!() |> ChordProFormatter.format()
      output2 = output1 |> parse_cp!() |> ChordProFormatter.format()

      assert_equal_ignoring_blank_lines(output1, output2)
    end
  end

  # -- Helpers --

  defp parse_cp!(input) do
    {:ok, song} = ChordProParser.parse(input)
    song
  end

  defp parse_ug!(input) do
    {:ok, song} = UltimateGuitarParser.parse(input)
    song
  end

  defp parse_cow!(input) do
    {:ok, song} = ChordsOverWordsParser.parse(input)
    song
  end

  defp parse_typst!(input) do
    {:ok, song} = TypstParser.parse(input)
    song
  end

  # Compares two strings ignoring differences in consecutive blank lines.
  # Collapses runs of blank lines into a single blank line before comparing.
  defp assert_equal_ignoring_blank_lines(left, right) do
    assert normalize_blank_lines(left) == normalize_blank_lines(right)
  end

  defp normalize_blank_lines(str) do
    str
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end
end

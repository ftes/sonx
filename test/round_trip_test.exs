defmodule Sonx.RoundTripTest do
  @moduledoc """
  Roundtrip tests:
  - Same-format: input == format(parse(input))
  - Cross-format: format_b(parse_a(input)) == format_b(parse_b(format_b(parse_a(input))))
  """

  use ExUnit.Case, async: true

  # {format_atom, fixture_dir, file_glob}
  @formats [
    {:chord_pro, "test/support/fixtures/chord_pro", "*.cho"},
    {:chords_over_words, "test/support/fixtures/chords_over_words", "*.txt"},
    {:ultimate_guitar, "test/support/fixtures/ultimate_guitar", "simple.txt"},
    {:typst, "test/support/fixtures/typst", "*.typ"}
  ]

  # --- Same-format: input == format(parse(input)) ---

  for {format, dir, glob} <- @formats,
      fixture <- Path.wildcard(Path.join(dir, glob)) do
    basename = Path.basename(fixture)

    test "same-format #{format}/#{basename}: input == format(parse(input))" do
      input = File.read!(unquote(fixture))
      {:ok, song} = Sonx.parse(unquote(format), input)
      output = Sonx.format(unquote(format), song)

      assert normalize(unquote(format), input) == normalize(unquote(format), output)
    end
  end

  # --- Cross-format: format_b is idempotent after parse_a ---

  for {source_format, dir, glob} <- @formats,
      fixture <- Path.wildcard(Path.join(dir, glob)),
      {target_format, _, _} <- @formats,
      source_format != target_format do
    basename = Path.basename(fixture)

    test "cross-format #{source_format}/#{basename} → #{target_format}: idempotent" do
      input = File.read!(unquote(fixture))
      {:ok, song1} = Sonx.parse(unquote(source_format), input)
      output1 = Sonx.format(unquote(target_format), song1)
      {:ok, song2} = Sonx.parse(unquote(target_format), output1)
      output2 = Sonx.format(unquote(target_format), song2)

      assert normalize(unquote(target_format), output1) ==
               normalize(unquote(target_format), output2)
    end
  end

  # --- Per-format normalization ---

  defp normalize(:chords_over_words, str) do
    str
    |> normalize_whitespace()
    # Section label numbers are lossy ("Verse 1:" → start_of_verse → "Verse:")
    |> String.replace(~r/^((?:Verse|Chorus|Bridge|Intro|Outro)\b).*$/m, "\\1")
  end

  defp normalize(_format, str), do: normalize_whitespace(str)

  defp normalize_whitespace(str) do
    str
    |> String.trim()
    |> String.replace(~r/\n{3,}/, "\n\n")
  end
end

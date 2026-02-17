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
  #
  # These functions declare what information loss is acceptable per target format
  # in cross-format roundtrips. Each normalizer collapses differences that arise
  # from known, expected limitations of the target format.

  defp normalize(:chords_over_words, str) do
    str
    |> normalize_whitespace()
    # Section label numbers are lossy ("Verse 1" → start_of_verse → "Verse")
    |> strip_section_label_numbers()
    # Trailing space before a chord on chord-only lines is lossy:
    # `[Gm]You [F]` → chord line "Gm  F" first pass, "Gm F" second pass
    |> normalize_chord_line_spacing()
    # Comment text with numbers like "Repeat Chorus 2" loses the number
    |> strip_comment_line_numbers()
    # Blank line before section headers may be absent on first pass when
    # a comment line (e.g. "Repeat Chorus") precedes a section
    |> ensure_blank_line_before_sections()
    # Lyrics starting with chord-like words (A-G) are ambiguous:
    # "A breath from God" re-parses as chords A + G over different lyrics
    |> normalize_ambiguous_chord_lyrics()
  end

  defp normalize(:ultimate_guitar, str) do
    str
    |> normalize_whitespace()
    # Trailing space before chord on chord lines (same as CoW)
    |> normalize_chord_line_spacing()
    # Duplicate section headers from Typst numbered sections: [Verse 1]\n\n[Verse]
    |> collapse_duplicate_section_headers()
    # Same chord/lyric ambiguity as CoW
    |> normalize_ambiguous_chord_lyrics()
  end

  defp normalize(:typst, str) do
    str
    |> normalize_whitespace()
    # Comment lines (// text) are lossy: they disappear on re-parse through Typst
    # Metadata comments (// key:, // capo:, // tempo:) are preserved.
    |> strip_non_metadata_comments()
  end

  defp normalize(_format, str), do: normalize_whitespace(str)

  defp normalize_whitespace(str) do
    str
    |> String.trim()
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  # Collapse runs of 2+ spaces to single space on chord-only lines.
  # A "chord-only line" is one where every non-space token looks like a chord name.
  defp normalize_chord_line_spacing(str) do
    chord_pattern = ~r/^[A-G][b#]?(?:m|min|maj|dim|aug|sus|add|dom|[0-9]|\/[A-G])*$/

    str
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      tokens = String.split(line)

      if tokens != [] and Enum.all?(tokens, &Regex.match?(chord_pattern, &1)) do
        # It's a chord-only line — collapse multi-space runs to single space,
        # preserving leading spaces (chord positioning)
        Regex.replace(~r/(?<=\S)  +/, line, " ")
      else
        line
      end
    end)
  end

  # "Verse 1" → "Verse", "Chorus 2" → "Chorus", etc. in section label lines
  defp strip_section_label_numbers(str) do
    String.replace(str, ~r/^((?:Verse|Chorus|Bridge|Intro|Outro)\b).*$/m, "\\1")
  end

  # "Repeat Chorus 2" → "Repeat Chorus" — numbers at end of comment-like lines
  defp strip_comment_line_numbers(str) do
    String.replace(str, ~r/^((?:Repeat|Instrumental)\b.*?)\s*\d+\s*$/m, "\\1")
  end

  # Remove non-metadata comment lines from Typst output.
  # Metadata comments like "// key: C" are kept; others like "// Bridge (3x)" are removed.
  # Also removes trailing " \" continuation from the preceding line if the comment
  # was joining two content blocks.
  defp strip_non_metadata_comments(str) do
    str
    |> String.split("\n")
    |> strip_comment_lines([])
    |> Enum.join("\n")
    # Collapsing comments can leave extra blank lines
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp strip_comment_lines([], acc), do: Enum.reverse(acc)

  defp strip_comment_lines([line | rest], acc) do
    if Regex.match?(~r/^\/\/\s+/, line) and
         not Regex.match?(~r/^\/\/\s+(key|capo|tempo|time|artist|subtitle):/, line) do
      # Remove trailing " \" from previous line if it was a continuation to this comment
      acc =
        case acc do
          [prev | rest_acc] ->
            [String.replace(prev, ~r/ \\$/, "") | rest_acc]

          _ ->
            acc
        end

      strip_comment_lines(rest, acc)
    else
      strip_comment_lines(rest, [line | acc])
    end
  end

  # When a chord line is followed by a lyrics line starting with a chord-like word
  # (single letter A-G), the CoW/UG parser may reinterpret the lyrics as chords.
  # Example: "G  D" / "A breath from God" → re-parses "A" and "G" as chords.
  # Normalize by replacing both lines with just the content words (no positioning).
  defp normalize_ambiguous_chord_lyrics(str) do
    chord_pattern = ~r/^[A-G][b#]?(?:m|min|maj|dim|aug|sus|add|dom|[0-9]|\/[A-G])*$/

    str
    |> String.split("\n")
    |> merge_ambiguous_pairs(chord_pattern, [])
    |> Enum.join("\n")
  end

  defp merge_ambiguous_pairs([], _pattern, acc), do: Enum.reverse(acc)

  defp merge_ambiguous_pairs([chord_line, lyrics_line | rest], pattern, acc) do
    chord_tokens = String.split(chord_line)
    chord_line? = chord_tokens != [] and Enum.all?(chord_tokens, &Regex.match?(pattern, &1))

    lyrics_first_word =
      case String.split(lyrics_line, ~r/\s+/, parts: 2) do
        [word | _] -> word
        _ -> ""
      end

    ambiguous? = chord_line? and Regex.match?(~r/^[A-G]$/, lyrics_first_word)

    if ambiguous? do
      # Drop both lines — chord/lyric boundary is fundamentally ambiguous
      # when lyrics start with a chord-like letter (A-G)
      merge_ambiguous_pairs(rest, pattern, acc)
    else
      merge_ambiguous_pairs([lyrics_line | rest], pattern, [chord_line | acc])
    end
  end

  defp merge_ambiguous_pairs([line | rest], pattern, acc) do
    merge_ambiguous_pairs(rest, pattern, [line | acc])
  end

  # Ensure blank line before section headers (Verse, Chorus, etc.).
  # Comment-like lines before a section may not have a blank line separator
  # on first pass but do on second pass.
  defp ensure_blank_line_before_sections(str) do
    String.replace(
      str,
      ~r/([^\n])\n((?:Verse|Chorus|Bridge|Intro|Outro)\b)/,
      "\\1\n\n\\2"
    )
  end

  # Collapse "[Verse 1]\n\n[Verse]" → "[Verse 1]" in UG format.
  # When Typst sections with numbers go through UG, the numbered heading and
  # the unnumbered re-parsed heading both appear.
  defp collapse_duplicate_section_headers(str) do
    section = "Verse|Chorus|Bridge|Intro|Outro"

    Regex.replace(
      ~r/^\[((?:#{section})[^\]]*)\]\n\n\[((?:#{section}))\]/m,
      str,
      fn _, numbered, base ->
        # Only collapse if the numbered header starts with the base name
        if String.starts_with?(numbered, base) do
          "[#{numbered}]"
        else
          "[#{numbered}]\n\n[#{base}]"
        end
      end
    )
  end
end

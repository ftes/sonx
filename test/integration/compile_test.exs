defmodule Sonx.Integration.CompileTest do
  @moduledoc """
  Integration tests that verify formatter output compiles with real tools.

  Requires external tools: typst, pdflatex (texlive + songs package), chordpro.
  Excluded from `mix test` by default. Run with `mix test.integration`.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  # All parseable input formats and their fixture files
  @inputs [
    {:chord_pro, "test/support/fixtures/chord_pro", "*.cho"},
    {:chords_over_words, "test/support/fixtures/chords_over_words", "*.txt"},
    {:ultimate_guitar, "test/support/fixtures/ultimate_guitar", "simple.txt"},
    {:typst, "test/support/fixtures/typst", "*.typ"},
    {:latex_songs, "test/support/fixtures/latex_songs", "*.tex"}
  ]

  # Formatter option combinations to test
  @typst_option_sets [
    [],
    [chord_diagrams: true],
    [normalize_chords: true],
    [unicode_accidentals: true]
  ]

  @latex_option_sets [
    [],
    [chord_diagrams: true],
    [normalize_chords: true],
    [unicode_accidentals: true]
  ]

  @chordpro_option_sets [
    {[], []},
    {[], ["--diagrams=all"]},
    {[normalize_chords: true], []},
    {[unicode_accidentals: true], []}
  ]

  # --- Typst ---

  # ChordsOverWords/UltimateGuitar section headers (e.g. [Verse]) become chord-like items
  # that conchord's sized-chordlib can't parse. Skip chord_diagrams for those inputs.
  for {input_format, dir, glob} <- @inputs,
      fixture <- Path.wildcard(Path.join(dir, glob)),
      opts <- @typst_option_sets,
      not (input_format in ~w[chords_over_words ultimate_guitar]a and
             Keyword.get(opts, :chord_diagrams, false) != false) do
    basename = Path.basename(fixture)
    opts_label = if opts == [], do: "default", else: inspect(opts)

    @tag :integration
    test "typst compiles: #{input_format}/#{basename} (#{opts_label})" do
      input = File.read!(unquote(fixture))
      {:ok, song} = Sonx.parse(unquote(input_format), input)
      output = Sonx.format(:typst, song, unquote(Macro.escape(opts)))

      compile_typst!(output)
    end
  end

  # --- LaTeX (songs package) ---

  for {input_format, dir, glob} <- @inputs,
      fixture <- Path.wildcard(Path.join(dir, glob)),
      opts <- @latex_option_sets do
    basename = Path.basename(fixture)
    opts_label = if opts == [], do: "default", else: inspect(opts)

    @tag :integration
    test "latex compiles: #{input_format}/#{basename} (#{opts_label})" do
      input = File.read!(unquote(fixture))
      {:ok, song} = Sonx.parse(unquote(input_format), input)
      output = Sonx.format(:latex_songs, song, unquote(Macro.escape(opts)))

      compile_latex!(output)
    end
  end

  # --- ChordPro ---

  for {input_format, dir, glob} <- @inputs,
      fixture <- Path.wildcard(Path.join(dir, glob)),
      {opts, extra_args} <- @chordpro_option_sets do
    basename = Path.basename(fixture)

    opts_label =
      case {opts, extra_args} do
        {[], []} -> "default"
        {[], args} -> Enum.join(args, " ")
        {o, []} -> inspect(o)
        {o, args} -> "#{inspect(o)} #{Enum.join(args, " ")}"
      end

    @tag :integration
    test "chordpro compiles: #{input_format}/#{basename} (#{opts_label})" do
      input = File.read!(unquote(fixture))
      {:ok, song} = Sonx.parse(unquote(input_format), input)
      output = Sonx.format(:chord_pro, song, unquote(Macro.escape(opts)))

      compile_chordpro!(output, unquote(Macro.escape(extra_args)))
    end
  end

  # --- Helpers ---

  defp compile_typst!(typst_source) do
    tmp_dir = mktmpdir!()
    typ_path = Path.join(tmp_dir, "test.typ")
    pdf_path = Path.join(tmp_dir, "test.pdf")
    File.write!(typ_path, typst_source)

    {output, exit_code} = System.cmd("typst", ["compile", typ_path, pdf_path], stderr_to_stdout: true)

    assert exit_code == 0,
           "typst compile failed (exit #{exit_code}):\n#{output}\n\nSource:\n#{typst_source}"
  end

  defp compile_latex!(latex_fragment) do
    document = """
    \\documentclass{article}
    \\usepackage[utf8]{inputenc}
    \\usepackage{songs}
    \\begin{document}
    \\begin{songs}{}
    #{latex_fragment}
    \\end{songs}
    \\end{document}
    """

    tmp_dir = mktmpdir!()
    tex_path = Path.join(tmp_dir, "test.tex")
    File.write!(tex_path, document)

    {output, exit_code} =
      System.cmd("pdflatex", ["-interaction=nonstopmode", "-halt-on-error", "test.tex"],
        cd: tmp_dir,
        stderr_to_stdout: true
      )

    assert exit_code == 0,
           "pdflatex failed (exit #{exit_code}):\n#{output}\n\nSource:\n#{document}"
  end

  defp compile_chordpro!(chordpro_source, extra_args) do
    tmp_dir = mktmpdir!()
    cho_path = Path.join(tmp_dir, "test.cho")
    pdf_path = Path.join(tmp_dir, "test.pdf")
    File.write!(cho_path, chordpro_source)

    args = extra_args ++ [cho_path, "--output=#{pdf_path}"]
    {output, exit_code} = System.cmd("chordpro", args, stderr_to_stdout: true)

    assert exit_code == 0,
           "chordpro failed (exit #{exit_code}):\n#{output}\n\nSource:\n#{chordpro_source}"
  end

  defp mktmpdir! do
    tmp_dir = Path.join(System.tmp_dir!(), "sonx_integration_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end
end

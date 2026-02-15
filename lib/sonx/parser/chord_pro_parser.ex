defmodule Sonx.Parser.ChordProParser do
  @moduledoc """
  Parses ChordPro format chord sheets into Song structs.

  Supports:
  - Directives: `{title: My Song}`, `{start_of_chorus}`, etc.
  - Inline chords: `[Am]lyrics here`
  - Annotations: `[*annotation]lyrics`
  - Comments: `# comment text`
  - Ternary meta expressions: `%{variable|true|false}`
  - Soft line breaks: `\\ ` (backslash-space)
  - Chord definitions: `{define: ...}`
  """

  @behaviour Sonx.Parser

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Literal,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  alias Sonx.SongBuilder

  @impl true
  @spec parse(String.t(), keyword()) :: {:ok, Song.t()} | {:error, term()}
  def parse(input, _opts \\ []) do
    song = do_parse(input)
    {:ok, song}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc "Parses a ChordPro string or raises on failure."
  @spec parse!(String.t(), keyword()) :: Song.t()
  def parse!(input, opts \\ []) do
    case parse(input, opts) do
      {:ok, song} -> song
      {:error, reason} -> raise "ChordPro parse error: #{reason}"
    end
  end

  # --- Core parsing logic ---

  defp do_parse(input) do
    lines = split_lines(input)

    builder =
      Enum.reduce(lines, SongBuilder.new(), fn line_str, builder ->
        parse_line(builder, line_str)
      end)

    SongBuilder.build(builder)
  end

  defp split_lines(input) do
    input
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n")
  end

  defp parse_line(builder, line_str) do
    trimmed = String.trim(line_str)

    cond do
      trimmed == "" ->
        # Empty line
        SongBuilder.add_line(builder)

      String.starts_with?(trimmed, "#") ->
        # Comment line
        content = String.slice(trimmed, 1..-1//1)

        builder
        |> SongBuilder.add_line()
        |> SongBuilder.add_item(Comment.new(content))

      match_directive?(trimmed) ->
        # Directive line: {tag: value}
        parse_directive_line(builder, trimmed)

      true ->
        # Content line with lyrics and/or chords
        parse_content_line(builder, line_str)
    end
  end

  # --- Directive parsing ---

  @directive_regex ~r/^\{([^}]*)\}$/
  @tag_with_value_regex ~r/^([a-zA-Z_][a-zA-Z0-9_]*)(?:\s*:\s*(.*))?$/

  defp match_directive?(str) do
    Regex.match?(@directive_regex, String.trim(str))
  end

  defp parse_directive_line(builder, line_str) do
    trimmed = String.trim(line_str)

    case Regex.run(@directive_regex, trimmed) do
      [_, inner] ->
        tag = parse_tag_inner(inner)

        builder
        |> SongBuilder.add_line()
        |> SongBuilder.add_item(tag)

      _ ->
        # Shouldn't happen since we checked match_directive? first
        parse_content_line(builder, line_str)
    end
  end

  defp parse_tag_inner(inner) do
    trimmed = String.trim(inner)

    case Regex.run(@tag_with_value_regex, trimmed) do
      [_, name, value] ->
        {value, attributes} = parse_tag_value_and_attributes(String.trim(value))
        Tag.new(name, value, attributes: attributes)

      [_, name] ->
        Tag.new(name)

      _ ->
        Tag.new(trimmed)
    end
  end

  # Parse attributes like: label="Chorus 1" id="v2"
  @attribute_regex ~r/([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"(?:\s+|$)/

  defp parse_tag_value_and_attributes(value_str) do
    # Check if the value contains key="value" patterns
    if Regex.match?(@attribute_regex, value_str) do
      attrs =
        Regex.scan(@attribute_regex, value_str)
        |> Map.new(fn [_, k, v] -> {k, v} end)

      # The "simple value" is whatever doesn't match the attribute pattern
      simple_value =
        Regex.replace(@attribute_regex, value_str, "")
        |> String.trim()

      {simple_value, attrs}
    else
      {value_str, %{}}
    end
  end

  # --- Content line parsing (lyrics with inline chords) ---

  defp parse_content_line(builder, line_str) do
    items = parse_inline_content(line_str)

    builder = SongBuilder.add_line(builder)

    Enum.reduce(items, builder, fn item, b ->
      SongBuilder.add_item(b, item)
    end)
  end

  @doc false
  @spec parse_inline_content(String.t()) :: [Sonx.ChordSheet.item()]
  def parse_inline_content(str) do
    parse_tokens(str, [], "")
  end

  # Recursive token parser for content lines
  defp parse_tokens("", acc, current_lyrics) do
    finalize_tokens(acc, current_lyrics)
  end

  # Escape sequences
  defp parse_tokens("\\\\" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "\\")
  end

  defp parse_tokens("\\[" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "[")
  end

  defp parse_tokens("\\{" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "{")
  end

  defp parse_tokens("\\%" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "%")
  end

  defp parse_tokens("\\]" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "]")
  end

  defp parse_tokens("\\#" <> rest, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> "#")
  end

  # Soft line break: backslash followed by space
  defp parse_tokens("\\ " <> rest, acc, current_lyrics) do
    acc = flush_lyrics(acc, current_lyrics)
    acc = acc ++ [SoftLineBreak.new()]
    parse_tokens(rest, acc, "")
  end

  # Annotation: [*annotation]
  defp parse_tokens("[*" <> rest, acc, current_lyrics) do
    case extract_until(rest, "]") do
      {annotation, after_bracket} ->
        {lyrics, remaining} = extract_lyrics_after_chord(after_bracket)
        acc = flush_lyrics(acc, current_lyrics)
        pair = ChordLyricsPair.new("", lyrics, annotation)
        parse_tokens(remaining, acc ++ [pair], "")

      nil ->
        parse_tokens(rest, acc, current_lyrics <> "[*")
    end
  end

  # Inline chord: [chord]
  defp parse_tokens("[" <> rest, acc, current_lyrics) do
    case extract_until(rest, "]") do
      {chord_str, after_bracket} ->
        {lyrics, remaining} = extract_lyrics_after_chord(after_bracket)
        acc = flush_lyrics(acc, current_lyrics)
        pair = ChordLyricsPair.new(chord_str, lyrics)
        parse_tokens(remaining, acc ++ [pair], "")

      nil ->
        # No closing bracket — treat as literal
        parse_tokens(rest, acc, current_lyrics <> "[")
    end
  end

  # Inline directive: {tag: value} within a content line
  defp parse_tokens("{" <> rest, acc, current_lyrics) do
    case extract_until(rest, "}") do
      {inner, after_brace} ->
        acc = flush_lyrics(acc, current_lyrics)
        tag = parse_tag_inner(inner)
        parse_tokens(after_brace, acc ++ [tag], "")

      nil ->
        parse_tokens(rest, acc, current_lyrics <> "{")
    end
  end

  # Ternary meta expression: %{variable|true|false}
  defp parse_tokens("%{" <> rest, acc, current_lyrics) do
    case extract_until(rest, "}") do
      {inner, after_brace} ->
        acc = flush_lyrics(acc, current_lyrics)
        ternary = parse_ternary(inner)
        parse_tokens(after_brace, acc ++ [ternary], "")

      nil ->
        parse_tokens(rest, acc, current_lyrics <> "%{")
    end
  end

  # Regular character
  defp parse_tokens(<<char::utf8, rest::binary>>, acc, current_lyrics) do
    parse_tokens(rest, acc, current_lyrics <> <<char::utf8>>)
  end

  defp flush_lyrics(acc, ""), do: acc

  defp flush_lyrics(acc, lyrics) do
    # If the last item is a ChordLyricsPair with no lyrics, append to it
    case List.last(acc) do
      %ChordLyricsPair{lyrics: ""} ->
        List.update_at(acc, -1, fn pair -> %{pair | lyrics: lyrics} end)

      _ ->
        acc ++ [ChordLyricsPair.new("", lyrics)]
    end
  end

  defp finalize_tokens(acc, "") when acc != [], do: acc

  defp finalize_tokens(acc, current_lyrics) do
    flush_lyrics(acc, current_lyrics)
  end

  defp extract_until(str, delimiter) do
    case :binary.match(str, delimiter) do
      {pos, len} ->
        before = binary_part(str, 0, pos)
        after_delim = binary_part(str, pos + len, byte_size(str) - pos - len)
        {before, after_delim}

      :nomatch ->
        nil
    end
  end

  defp extract_lyrics_after_chord(str) do
    # Extract lyrics until we hit another [ or { or %{ or end of string
    extract_lyrics(str, "")
  end

  defp extract_lyrics("", acc), do: {acc, ""}
  defp extract_lyrics("[" <> _ = rest, acc), do: {acc, rest}
  defp extract_lyrics("{" <> _ = rest, acc), do: {acc, rest}
  defp extract_lyrics("%{" <> _ = rest, acc), do: {acc, rest}

  defp extract_lyrics("\\\\" <> rest, acc), do: extract_lyrics(rest, acc <> "\\")
  defp extract_lyrics("\\[" <> rest, acc), do: extract_lyrics(rest, acc <> "[")
  defp extract_lyrics("\\]" <> rest, acc), do: extract_lyrics(rest, acc <> "]")
  defp extract_lyrics("\\{" <> rest, acc), do: extract_lyrics(rest, acc <> "{")
  defp extract_lyrics("\\%" <> rest, acc), do: extract_lyrics(rest, acc <> "%")

  # Soft line break in lyrics — stop and return, let main parser handle it
  defp extract_lyrics("\\ " <> _ = rest, acc), do: {acc, rest}

  defp extract_lyrics(<<char::utf8, rest::binary>>, acc) do
    extract_lyrics(rest, acc <> <<char::utf8>>)
  end

  # --- Ternary parsing ---

  defp parse_ternary(inner) do
    parts = split_ternary_parts(inner)

    case parts do
      [variable_part] ->
        {variable, value_test} = parse_variable_and_test(variable_part)
        Ternary.new(variable: variable, value_test: value_test)

      [variable_part, true_expr] ->
        {variable, value_test} = parse_variable_and_test(variable_part)

        Ternary.new(
          variable: variable,
          value_test: value_test,
          true_expression: parse_ternary_expression(true_expr)
        )

      [variable_part, true_expr, false_expr | _] ->
        {variable, value_test} = parse_variable_and_test(variable_part)

        Ternary.new(
          variable: variable,
          value_test: value_test,
          true_expression: parse_ternary_expression(true_expr),
          false_expression: parse_ternary_expression(false_expr)
        )
    end
  end

  defp split_ternary_parts(str) do
    # Split on | but not inside nested %{...}
    split_on_pipe(str, "", [], 0)
  end

  defp split_on_pipe("", current, parts, _depth) do
    parts ++ [current]
  end

  defp split_on_pipe("%{" <> rest, current, parts, depth) do
    split_on_pipe(rest, current <> "%{", parts, depth + 1)
  end

  defp split_on_pipe("}" <> rest, current, parts, depth) when depth > 0 do
    split_on_pipe(rest, current <> "}", parts, depth - 1)
  end

  defp split_on_pipe("|" <> rest, current, parts, 0) do
    split_on_pipe(rest, "", parts ++ [current], 0)
  end

  defp split_on_pipe(<<char::utf8, rest::binary>>, current, parts, depth) do
    split_on_pipe(rest, current <> <<char::utf8>>, parts, depth)
  end

  defp parse_variable_and_test(str) do
    trimmed = String.trim(str)

    case String.split(trimmed, "=", parts: 2) do
      [variable, test] -> {variable, test}
      [variable] -> {variable, nil}
    end
  end

  defp parse_ternary_expression(""), do: []

  defp parse_ternary_expression(str) do
    # For now, treat as a literal. Nested ternaries will be handled
    # if we encounter %{ within the expression.
    if String.contains?(str, "%{") do
      parse_expression_tokens(str, [])
    else
      [Literal.new(str)]
    end
  end

  defp parse_expression_tokens("", acc), do: acc

  defp parse_expression_tokens("%{" <> rest, acc) do
    case extract_until(rest, "}") do
      {inner, remaining} ->
        ternary = parse_ternary(inner)
        parse_expression_tokens(remaining, acc ++ [ternary])

      nil ->
        acc ++ [Literal.new("%{" <> rest)]
    end
  end

  defp parse_expression_tokens(str, acc) do
    case :binary.match(str, "%{") do
      {pos, _len} ->
        before = binary_part(str, 0, pos)
        rest = binary_part(str, pos, byte_size(str) - pos)
        acc = if before == "", do: acc, else: acc ++ [Literal.new(before)]
        parse_expression_tokens(rest, acc)

      :nomatch ->
        acc ++ [Literal.new(str)]
    end
  end
end

defmodule Sonx.Parser.ChordParser do
  @moduledoc """
  NimbleParsec-based parser for individual chord strings.

  Supports all 4 chord types: symbol, solfege, numeric, numeral.
  Examples: "Am7", "Ebsus4/Bb", "#4/b3", "IV", "Do#m"
  """

  import NimbleParsec

  alias Sonx.{Chord, Key}

  # --- Helpers / Building blocks ---

  accidental = ascii_char([?#, ?b]) |> map({__MODULE__, :char_to_accidental, []})

  # Quality: m (not followed by 'a' for 'maj'), dim, aug, sus4, sus2, sus, or empty
  quality =
    choice([
      string("m") |> lookahead_not(ascii_char([?a, ?A])) |> replace("m"),
      string("dim") |> replace("dim"),
      string("Dim") |> replace("dim"),
      string("DIM") |> replace("dim"),
      string("aug") |> replace("aug"),
      string("Aug") |> replace("aug"),
      string("AUG") |> replace("aug"),
      string("sus4") |> replace("sus4"),
      string("sus2") |> replace("sus2"),
      string("sus") |> replace("sus"),
      empty() |> replace(nil)
    ])

  # Extension characters: alphanumeric, #, +, -, o, ♭, ♯, Δ
  extension_chars =
    utf8_char([?a..?z, ?A..?Z, ?0..?9, ?#, ?+, ?-, ?o, 0x266D, 0x266F, 0x0394])

  # Extensions can be parenthesized or bare
  extension =
    choice([
      ignore(ascii_char([?(]))
      |> times(extension_chars, min: 1)
      |> ignore(ascii_char([?)]))
      |> reduce({__MODULE__, :wrap_parens, []}),
      times(extension_chars, min: 1)
      |> reduce({List, :to_string, []})
    ])

  extensions = times(extension, min: 1) |> reduce({Enum, :join, [""]})

  suffix =
    quality
    |> optional(extensions)
    |> reduce({__MODULE__, :build_suffix, []})

  # --- Symbol chord ---

  symbol_root = ascii_char([?A..?G, ?a..?g]) |> reduce({List, :to_string, []})

  symbol_bass =
    ignore(string("/"))
    |> concat(symbol_root)
    |> optional(accidental)
    |> reduce({__MODULE__, :build_bass, []})

  symbol_chord =
    symbol_root
    |> optional(accidental)
    |> concat(suffix)
    |> optional(symbol_bass)
    |> reduce({__MODULE__, :build_symbol_chord, []})

  # bass-only symbol
  symbol_bass_only =
    symbol_bass
    |> reduce({__MODULE__, :build_bass_only_chord, [:symbol]})

  # --- Solfege chord ---

  # Must be careful: "Fa" should not match "Fadd" or "Faug"
  solfege_fa =
    choice([
      string("Fa")
      |> lookahead_not(choice([string("dd"), string("DD"), string("ug"), string("UG")])),
      string("fa") |> lookahead_not(choice([string("dd"), string("ug")]))
    ])

  solfege_root =
    choice([
      string("Sol") |> replace("Sol"),
      string("sol") |> replace("sol"),
      string("Do") |> replace("Do"),
      string("do") |> replace("do"),
      string("Re") |> replace("Re"),
      string("re") |> replace("re"),
      string("Mi") |> replace("Mi"),
      string("mi") |> replace("mi"),
      solfege_fa,
      string("La") |> replace("La"),
      string("la") |> replace("la"),
      string("Si") |> replace("Si"),
      string("si") |> replace("si")
    ])

  solfege_bass =
    ignore(string("/"))
    |> concat(solfege_root)
    |> optional(accidental)
    |> reduce({__MODULE__, :build_bass, []})

  solfege_chord =
    solfege_root
    |> optional(accidental)
    |> concat(suffix)
    |> optional(solfege_bass)
    |> reduce({__MODULE__, :build_solfege_chord, []})

  solfege_bass_only =
    solfege_bass
    |> reduce({__MODULE__, :build_bass_only_chord, [:solfege]})

  # --- Numeral chord ---

  numeral_root =
    choice([
      string("III") |> replace("III"),
      string("iii") |> replace("iii"),
      string("VII") |> replace("VII"),
      string("vii") |> replace("vii"),
      string("II") |> replace("II"),
      string("ii") |> replace("ii"),
      string("IV") |> replace("IV"),
      string("iv") |> replace("iv"),
      string("VI") |> replace("VI"),
      string("vi") |> replace("vi"),
      string("I") |> replace("I"),
      string("i") |> replace("i"),
      string("V") |> replace("V"),
      string("v") |> replace("v")
    ])

  numeral_bass =
    ignore(string("/"))
    |> optional(accidental)
    |> concat(numeral_root)
    |> reduce({__MODULE__, :build_numeral_bass, []})

  numeral_chord =
    optional(accidental)
    |> concat(numeral_root)
    |> concat(suffix)
    |> optional(numeral_bass)
    |> reduce({__MODULE__, :build_numeral_chord, []})

  numeral_bass_only =
    numeral_bass
    |> reduce({__MODULE__, :build_bass_only_chord, [:numeral]})

  # --- Numeric chord ---

  numeric_root = ascii_char([?1..?7]) |> reduce({List, :to_string, []})

  numeric_bass =
    ignore(string("/"))
    |> optional(accidental)
    |> concat(numeric_root)
    |> reduce({__MODULE__, :build_numeral_bass, []})

  numeric_chord =
    optional(accidental)
    |> concat(numeric_root)
    |> concat(suffix)
    |> optional(numeric_bass)
    |> reduce({__MODULE__, :build_numeric_chord, []})

  numeric_bass_only =
    numeric_bass
    |> reduce({__MODULE__, :build_bass_only_chord, [:numeric]})

  # --- Optional (parenthesized) wrapper ---

  inner_chord =
    choice([
      numeral_chord,
      numeric_chord,
      solfege_chord,
      symbol_chord,
      numeral_bass_only,
      numeric_bass_only,
      solfege_bass_only,
      symbol_bass_only
    ])

  optional_chord =
    ignore(string("("))
    |> concat(inner_chord)
    |> ignore(string(")"))
    |> map({__MODULE__, :mark_optional, []})

  # --- Top-level ---

  defparsec(
    :parse_chord,
    choice([optional_chord, inner_chord])
    |> eos()
  )

  # --- Public API ---

  @doc "Parses a chord string into a Chord struct."
  @spec parse(String.t()) :: Chord.t() | nil
  def parse(chord_string) do
    trimmed = String.trim(chord_string)
    if trimmed != "", do: do_parse(trimmed)
  end

  @doc "Parses a chord string or raises."
  @spec parse!(String.t()) :: Chord.t()
  def parse!(chord_string) do
    case parse(chord_string) do
      nil -> raise "Failed to parse chord: #{inspect(chord_string)}"
      chord -> chord
    end
  end

  defp do_parse(input) do
    case parse_chord(input) do
      {:ok, [chord], "", _, _, _} -> chord
      _ -> nil
    end
  end

  # --- Reducer / mapper functions (must be public for NimbleParsec) ---

  @doc false
  def char_to_accidental(?#), do: :sharp
  def char_to_accidental(?b), do: :flat

  @doc false
  def wrap_parens(chars) do
    "(" <> List.to_string(chars) <> ")"
  end

  @doc false
  def build_suffix([nil]), do: nil
  def build_suffix([nil, ext]), do: ext
  def build_suffix([q]), do: q
  def build_suffix([q, ext]) when is_binary(q) and is_binary(ext), do: q <> ext
  def build_suffix([]), do: nil

  @doc false
  def build_bass([root]), do: {:bass, root, :natural}
  def build_bass([root, acc]) when is_atom(acc), do: {:bass, root, acc}

  @doc false
  def build_numeral_bass([root]), do: {:bass, root, :natural}
  def build_numeral_bass([acc, root]) when is_atom(acc), do: {:bass, root, acc}

  @doc false
  def build_symbol_chord(parts) do
    {root_str, rest} = List.pop_at(parts, 0)
    {accidental, rest} = pop_accidental(rest)
    {suffix, rest} = pop_suffix(rest)
    bass_info = find_bass(rest)

    root_key = resolve_key(root_str, accidental, :symbol, suffix)
    bass_key = resolve_bass_key(bass_info, :symbol)

    %Chord{root: root_key, bass: bass_key, suffix: clean_suffix(suffix, root_key)}
  end

  @doc false
  def build_solfege_chord(parts) do
    {root_str, rest} = List.pop_at(parts, 0)
    {accidental, rest} = pop_accidental(rest)
    {suffix, rest} = pop_suffix(rest)
    bass_info = find_bass(rest)

    root_key = resolve_key(root_str, accidental, :solfege, suffix)
    bass_key = resolve_bass_key(bass_info, :solfege)

    %Chord{root: root_key, bass: bass_key, suffix: clean_suffix(suffix, root_key)}
  end

  @doc false
  def build_numeral_chord(parts) do
    {accidental, rest} = pop_accidental(parts)
    {root_str, rest} = List.pop_at(rest, 0)
    {suffix, rest} = pop_suffix(rest)
    bass_info = find_bass(rest)

    root_key = resolve_key(root_str, accidental, :numeral, suffix)
    bass_key = resolve_bass_key(bass_info, :numeral)

    %Chord{root: root_key, bass: bass_key, suffix: clean_suffix(suffix, root_key)}
  end

  @doc false
  def build_numeric_chord(parts) do
    {accidental, rest} = pop_accidental(parts)
    {root_str, rest} = List.pop_at(rest, 0)
    {suffix, rest} = pop_suffix(rest)
    bass_info = find_bass(rest)

    root_key = resolve_key(root_str, accidental, :numeric, suffix)
    bass_key = resolve_bass_key(bass_info, :numeric)

    %Chord{root: root_key, bass: bass_key, suffix: clean_suffix(suffix, root_key)}
  end

  @doc false
  def build_bass_only_chord([{:bass, root, acc}], chord_type) do
    bass_key = Key.parse(build_key_string(root, acc, chord_type))
    %Chord{root: nil, bass: bass_key, suffix: nil}
  end

  @doc false
  def mark_optional(%Chord{} = chord) do
    %{chord | optional: true}
  end

  # --- Internal helpers ---

  defp pop_accidental([acc | rest]) when acc in [:sharp, :flat], do: {acc, rest}
  defp pop_accidental(list), do: {:natural, list}

  defp pop_suffix([s | rest]) when is_binary(s), do: {s, rest}
  defp pop_suffix([nil | rest]), do: {nil, rest}
  defp pop_suffix(list), do: {nil, list}

  defp find_bass(rest) do
    Enum.find(rest, fn
      {:bass, _, _} -> true
      _ -> false
    end)
  end

  defp resolve_key(root_str, accidental, chord_type, suffix) do
    minor_marker = if suffix_starts_with_minor?(suffix), do: "m", else: ""

    key_string = build_key_string(root_str, accidental, chord_type) <> minor_marker

    Key.parse(key_string)
  end

  defp resolve_bass_key(nil, _chord_type), do: nil

  defp resolve_bass_key({:bass, root, acc}, chord_type) do
    key_string = build_key_string(root, acc, chord_type)
    Key.parse(key_string)
  end

  defp build_key_string(root, accidental, chord_type) when chord_type in [:numeric, :numeral] do
    acc_str =
      case accidental do
        :sharp -> "#"
        :flat -> "b"
        _ -> ""
      end

    acc_str <> root
  end

  defp build_key_string(root, accidental, _chord_type) do
    acc_str =
      case accidental do
        :sharp -> "#"
        :flat -> "b"
        _ -> ""
      end

    root <> acc_str
  end

  defp suffix_starts_with_minor?(nil), do: false
  defp suffix_starts_with_minor?(s), do: String.starts_with?(s, "m")

  # Remove leading "m" from suffix when the root key is already minor
  defp clean_suffix(nil, _key), do: nil

  defp clean_suffix(suffix, %Key{minor: true}) do
    suffix
  end

  defp clean_suffix(suffix, _key), do: suffix
end

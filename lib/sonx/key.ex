defmodule Sonx.Key do
  @moduledoc """
  Represents a musical key, such as Eb (symbol), #3 (numeric) or VII (numeral).

  Supports parsing, transposition, normalization, accidental switching,
  and conversion between 4 chord notation types.
  """

  use TypedStruct

  alias Sonx.Scales

  @type chord_type() :: :symbol | :solfege | :numeric | :numeral
  @type accidental() :: :sharp | :flat | :natural

  typedstruct do
    field(:grade, non_neg_integer() | nil, default: nil)
    field(:number, non_neg_integer() | nil, default: nil)
    field(:type, chord_type(), enforce: true)
    field(:accidental, accidental() | nil, default: nil)
    field(:minor, boolean(), default: false)
    field(:reference_key_grade, non_neg_integer() | nil, default: nil)
    field(:reference_key_mode, :major | :minor | nil, default: nil)
    field(:original_key_string, String.t() | nil, default: nil)
    field(:preferred_accidental, accidental() | nil, default: nil)
    field(:explicit_accidental, boolean(), default: false)
  end

  @key_types [:symbol, :solfege, :numeric, :numeral]

  @regexes %{
    symbol: ~r/^(?<key>(?<note>[A-Ga-g])(?<accidental>[#b])?)(?<minor>m)?$/,
    solfege: ~r/^(?<key>(?<note>Do|Re|Mi|Fa|Sol|La|Si|do|re|mi|fa|sol|la|si)(?<accidental>[#b])?)(?<minor>m)?$/,
    numeric: ~r/^(?<key>(?<accidental>[#b])?(?<note>[1-7]))(?<minor>m)?$/,
    numeral: ~r/^(?<key>(?<accidental>[#b])?(?<note>I{1,3}|IV|VI{0,2}|i{1,3}|iv|vi{0,2}))$/
  }

  @no_flat_grades [4, 11]
  @no_flat_numbers [1, 4]
  @no_sharp_grades [5, 0]
  @no_sharp_numbers [3, 7]

  # --- Parsing ---

  @doc "Parses a key string, trying all chord types. Returns nil if unparseable."
  @spec parse(String.t() | nil) :: t() | nil
  def parse(nil), do: nil
  def parse(""), do: nil

  def parse(key_string) do
    trimmed = String.trim(key_string)
    if trimmed != "", do: parse_any_type(trimmed, @key_types)
  end

  @doc "Parses a key string or raises on failure."
  @spec parse!(String.t()) :: t()
  def parse!(key_string) do
    case parse(key_string) do
      nil -> raise "Failed to parse key: #{inspect(key_string)}"
      key -> key
    end
  end

  @doc "Wraps a string or Key into a Key. Passes through Key structs."
  @spec wrap(t() | String.t() | nil) :: t() | nil
  def wrap(nil), do: nil
  def wrap(%__MODULE__{} = key), do: key
  def wrap(key_string) when is_binary(key_string), do: parse(key_string)

  @doc "Wraps a string or Key into a Key, raising on failure."
  @spec wrap!(t() | String.t()) :: t()
  def wrap!(%__MODULE__{} = key), do: key

  def wrap!(key_string) when is_binary(key_string) do
    case parse(key_string) do
      nil -> raise "Failed to parse key: #{inspect(key_string)}"
      key -> key
    end
  end

  @doc "Calculates the semitone distance between two keys."
  @spec distance(t() | String.t(), t() | String.t()) :: integer()
  def distance(from, to) do
    from_key = wrap!(from)
    to_key = wrap!(to)
    shift_grade(effective_grade(to_key) - effective_grade(from_key))
  end

  # --- Grade computation ---

  @doc "Returns the effective chromatic grade of this key."
  @spec effective_grade(t()) :: non_neg_integer()
  def effective_grade(%__MODULE__{grade: nil} = key) do
    key |> ensure_grade() |> effective_grade()
  end

  def effective_grade(%__MODULE__{grade: grade, reference_key_grade: ref}) do
    shift_grade(grade + (ref || 0))
  end

  @doc "Shifts a grade into the 0..11 range."
  @spec shift_grade(integer()) :: non_neg_integer()
  def shift_grade(grade) when grade < 0, do: shift_grade(grade + 12)
  def shift_grade(grade), do: rem(grade, 12)

  # --- Transposition ---

  @doc "Transposes the key by delta semitones."
  @spec transpose(t(), integer()) :: t()
  def transpose(key, 0), do: key

  def transpose(key, delta) do
    original_accidental = key.accidental
    func = if delta < 0, do: &transpose_down/1, else: &transpose_up/1

    transposed =
      Enum.reduce(1..abs(delta), key, fn _, acc -> func.(acc) end)

    use_accidental(transposed, original_accidental)
  end

  @doc "Transposes up by one semitone."
  @spec transpose_up(t()) :: t()
  def transpose_up(key) do
    normalized = normalize(key)
    moved = change_grade(normalized, 1)

    moved =
      if key.accidental != nil or not can_be_sharp?(moved) do
        set(moved, accidental: nil)
      else
        set(moved, accidental: :sharp)
      end

    moved
    |> set(preferred_accidental: :sharp)
    |> normalize()
  end

  @doc "Transposes down by one semitone."
  @spec transpose_down(t()) :: t()
  def transpose_down(key) do
    normalized = normalize(key)
    moved = change_grade(normalized, -1)

    moved =
      if key.accidental != nil or not can_be_flat?(moved) do
        set(moved, accidental: nil)
      else
        set(moved, accidental: :flat)
      end

    set(moved, preferred_accidental: :flat)
  end

  @doc "Changes the grade by delta."
  @spec change_grade(t(), integer()) :: t()
  def change_grade(%__MODULE__{reference_key_grade: ref} = key, delta) when ref != nil do
    set(key, reference_key_grade: shift_grade(ref + delta))
  end

  def change_grade(key, delta) do
    key = ensure_grade(key)
    set(key, grade: shift_grade(key.grade + delta))
  end

  # --- Accidental operations ---

  @doc "Sets the accidental on the key."
  @spec use_accidental(t(), accidental()) :: t()
  def use_accidental(key, new_accidental) do
    key
    |> ensure_grade()
    |> set(accidental: new_accidental, explicit_accidental: new_accidental != nil)
  end

  @doc "Normalizes the key, removing impossible sharps/flats."
  @spec normalize(t()) :: t()
  def normalize(key) do
    key = ensure_grade(key)

    cond do
      key.accidental == :sharp and not can_be_sharp?(key) ->
        set(key, accidental: nil)

      key.accidental == :flat and not can_be_flat?(key) ->
        set(key, accidental: nil)

      true ->
        key
    end
  end

  @doc "Returns true if this key can have a sharp accidental."
  @spec can_be_sharp?(t()) :: boolean()
  def can_be_sharp?(%__MODULE__{number: num}) when num != nil do
    num not in @no_sharp_numbers
  end

  def can_be_sharp?(key) do
    effective_grade(key) not in @no_sharp_grades
  end

  @doc "Returns true if this key can have a flat accidental."
  @spec can_be_flat?(t()) :: boolean()
  def can_be_flat?(%__MODULE__{number: num}) when num != nil do
    num not in @no_flat_numbers
  end

  def can_be_flat?(key) do
    effective_grade(key) not in @no_flat_grades
  end

  # --- Type queries ---

  @spec type?(t(), chord_type()) :: boolean()
  def type?(key, type), do: key.type == type

  @spec minor?(t()) :: boolean()
  def minor?(key), do: key.minor

  # --- Conversion ---

  @doc "Converts the key to a chord symbol type."
  @spec to_chord_symbol(t(), t() | String.t() | nil) :: t()
  def to_chord_symbol(%__MODULE__{type: :symbol} = key, _reference_key), do: key

  def to_chord_symbol(key, reference_key) do
    convert_to_chord_type(key, reference_key, :symbol)
  end

  @doc "Converts the key to a solfege type."
  @spec to_chord_solfege(t(), t() | String.t() | nil) :: t()
  def to_chord_solfege(%__MODULE__{type: :solfege} = key, _reference_key), do: key

  def to_chord_solfege(key, reference_key) do
    convert_to_chord_type(key, reference_key, :solfege)
  end

  @doc "Converts the key to numeric type."
  @spec to_numeric(t(), t() | String.t() | nil) :: t()
  def to_numeric(%__MODULE__{type: :numeric} = key, _reference_key), do: key

  def to_numeric(%__MODULE__{type: :numeral} = key, _reference_key) do
    set(key, type: :numeric)
  end

  def to_numeric(key, reference_key) do
    ref = wrap!(reference_key)
    ref_grade = effective_grade(ref)
    ref_mode = if ref.minor, do: :minor, else: :major
    grade = shift_grade(effective_grade(key) - ref_grade)

    set(key,
      type: :numeric,
      grade: grade,
      reference_key_grade: 0,
      accidental: nil,
      preferred_accidental: ref.accidental,
      reference_key_mode: ref_mode
    )
  end

  @doc "Converts the key to numeral type."
  @spec to_numeral(t(), t() | String.t() | nil) :: t()
  def to_numeral(%__MODULE__{type: :numeral} = key, _reference_key), do: key

  def to_numeral(%__MODULE__{type: :numeric} = key, _reference_key) do
    set(key, type: :numeral)
  end

  def to_numeral(key, reference_key) do
    ref = wrap!(reference_key)
    ref_grade = effective_grade(ref)
    ref_mode = if ref.minor, do: :minor, else: :major
    grade = shift_grade(effective_grade(key) - ref_grade)

    set(key,
      type: :numeral,
      grade: grade,
      reference_key_grade: 0,
      accidental: nil,
      preferred_accidental: ref.accidental,
      reference_key_mode: ref_mode
    )
  end

  # --- String rendering ---

  @doc "Converts the key to a string representation."
  @spec to_string(t(), keyword()) :: String.t()
  def to_string(key, opts \\ []) do
    show_minor? = Keyword.get(opts, :show_minor, true)
    unicode_accidentals? = Keyword.get(opts, :unicode_accidentals, false)

    note = note_string(key)

    note =
      if unicode_accidentals? do
        note
        |> String.replace("#", "\u266F")
        |> String.replace("b", "\u266D")
      else
        note
      end

    minor_sign = if show_minor?, do: minor_sign(key), else: ""
    note <> minor_sign
  end

  @doc "Returns the note string for this key (without minor sign)."
  @spec note_string(t()) :: String.t()
  def note_string(%__MODULE__{grade: nil, number: nil}) do
    raise "Cannot render note: both grade and number are nil"
  end

  def note_string(%__MODULE__{grade: nil} = key) do
    note_for_number(key)
  end

  def note_string(key) do
    minor? =
      case key.reference_key_mode do
        :minor -> true
        :major -> false
        nil -> key.minor
      end

    Scales.grade_to_note(
      key.type,
      effective_grade(key),
      key.accidental,
      key.preferred_accidental,
      minor?
    )
  end

  # --- Equality ---

  @doc "Returns true if two keys are structurally equal."
  @spec equals?(t() | nil, t() | nil) :: boolean()
  def equals?(nil, nil), do: true
  def equals?(nil, _), do: false
  def equals?(_, nil), do: false

  def equals?(a, b) do
    a.grade == b.grade and
      a.number == b.number and
      a.accidental == b.accidental and
      a.preferred_accidental == b.preferred_accidental and
      a.type == b.type and
      a.minor == b.minor and
      a.reference_key_grade == b.reference_key_grade
  end

  @doc "Returns the relative major of a minor key."
  @spec relative_major(t()) :: t()
  def relative_major(key) do
    key
    |> change_grade(3)
    |> set(minor: false)
  end

  @doc "Returns the relative minor of a major key."
  @spec relative_minor(t()) :: t()
  def relative_minor(key) do
    key
    |> change_grade(-3)
    |> set(minor: true)
  end

  # --- Private helpers ---

  defp parse_any_type(_trimmed, []), do: nil

  defp parse_any_type(trimmed, [type | rest]) do
    case parse_as_type(trimmed, type) do
      nil -> parse_any_type(trimmed, rest)
      key -> key
    end
  end

  defp parse_as_type(trimmed, key_type) do
    regex = @regexes[key_type]

    case Regex.named_captures(regex, trimmed) do
      nil ->
        nil

      captures ->
        note = captures["note"]
        accidental = parse_accidental(captures["accidental"])
        minor? = minor?(note, key_type, captures["minor"])
        resolve(note, key_type, minor?, accidental)
    end
  end

  defp parse_accidental("#"), do: :sharp
  defp parse_accidental("b"), do: :flat
  defp parse_accidental(_), do: nil

  defp accidental_to_string(:sharp), do: "#"
  defp accidental_to_string(:flat), do: "b"
  defp accidental_to_string(:natural), do: ""
  defp accidental_to_string(nil), do: ""

  # For numerals, minor is determined by case (lowercase = minor) in resolve/4
  defp minor?(_note, :numeral, _minor), do: false
  defp minor?(_note, _type, "m"), do: true
  defp minor?(_note, _type, _), do: false

  defp resolve(note, key_type, minor?, accidental) when key_type in [:symbol, :solfege] do
    acc_key = accidental || :natural
    mode = if minor?, do: :minor, else: :major
    grade = Scales.to_grade(key_type, mode, acc_key, normalize_note_case(note, key_type))

    if grade do
      %__MODULE__{
        grade: 0,
        type: key_type,
        minor: minor?,
        accidental: accidental,
        preferred_accidental: accidental,
        reference_key_grade: grade,
        original_key_string: note
      }
    end
  end

  defp resolve(note, key_type, minor?, accidental) when key_type in [:numeric, :numeral] do
    number = get_number_from_key(note, key_type)

    # For numeral type, determine minor from case
    minor? =
      if key_type == :numeral do
        note == String.downcase(note)
      else
        minor?
      end

    if number do
      %__MODULE__{
        number: number,
        type: key_type,
        minor: minor?,
        accidental: accidental,
        preferred_accidental: accidental,
        original_key_string: note
      }
    end
  end

  defp normalize_note_case(note, :solfege) do
    String.capitalize(note)
  end

  defp normalize_note_case(note, :symbol) do
    String.upcase(String.at(note, 0)) <> String.slice(note, 1..-1//1)
  end

  defp get_number_from_key(key_string, :numeric) do
    case Integer.parse(key_string) do
      {n, ""} when n >= 1 and n <= 7 -> n
      _ -> nil
    end
  end

  defp get_number_from_key(key_string, :numeral) do
    upper = String.upcase(key_string)
    numerals = Scales.roman_numerals()

    case Enum.find_index(numerals, &(&1 == upper)) do
      nil -> nil
      idx -> idx + 1
    end
  end

  defp ensure_grade(%__MODULE__{grade: nil, number: nil} = _key) do
    raise "Cannot calculate grade: both grade and number are nil"
  end

  defp ensure_grade(%__MODULE__{grade: nil, number: number} = key) do
    acc_key = key.accidental || :natural
    mode = if key.minor, do: :minor, else: :major
    grade = Scales.to_grade(:numeric, mode, acc_key, Integer.to_string(number))

    %{key | grade: grade, number: nil}
  end

  defp ensure_grade(key), do: key

  defp convert_to_chord_type(key, reference_key, target_type) do
    acc = key.accidental
    key = ensure_grade(key)
    ref = wrap!(reference_key)

    converted =
      set(key,
        reference_key_grade: shift_grade(effective_grade(key) + effective_grade(ref)),
        grade: 0,
        type: target_type,
        accidental: nil,
        preferred_accidental: acc || ref.accidental
      )

    if acc do
      set(converted, preferred_accidental: acc, accidental: nil)
    else
      converted
    end
  end

  defp note_for_number(%__MODULE__{number: nil}) do
    raise "Cannot render note: number is nil"
  end

  defp note_for_number(%__MODULE__{type: :numeric} = key) do
    accidental_to_string(key.accidental) <> Integer.to_string(key.number)
  end

  defp note_for_number(%__MODULE__{type: :numeral} = key) do
    numerals = Scales.roman_numerals()
    numeral = Enum.at(numerals, key.number - 1)

    numeral =
      if key.minor do
        String.downcase(numeral)
      else
        numeral
      end

    accidental_to_string(key.accidental) <> numeral
  end

  defp minor_sign(%__MODULE__{minor: false}), do: ""
  defp minor_sign(%__MODULE__{type: :numeral}), do: ""
  defp minor_sign(%__MODULE__{type: type}) when type in [:symbol, :solfege], do: "m"
  defp minor_sign(%__MODULE__{type: :numeric} = _key), do: "m"

  defp set(key, attrs) do
    Enum.reduce(attrs, key, fn {field, value}, acc ->
      Map.put(acc, field, value)
    end)
  end

  defimpl String.Chars do
    def to_string(key) do
      Sonx.Key.to_string(key)
    end
  end
end

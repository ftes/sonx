defmodule Sonx.ChordSheet.Metadata do
  @moduledoc """
  Stores song metadata. Properties can be accessed using `get/2`.

  Values can be single strings or lists of strings (for multi-valued tags like artist).
  """

  use TypedStruct

  alias Sonx.ChordSheet.Tags
  alias Sonx.Key

  typedstruct do
    field(:data, %{String.t() => String.t() | [String.t()]}, default: %{})
  end

  @spec new(map()) :: t()
  def new(data \\ %{}) do
    %__MODULE__{data: data}
  end

  @doc "Returns true if the metadata contains the given key."
  @spec contains?(t(), String.t()) :: boolean()
  def contains?(%__MODULE__{data: data}, key), do: Map.has_key?(data, key)

  @doc "Adds a metadata value. Multiple values for the same key become a list."
  @spec add(t(), String.t(), String.t()) :: t()
  def add(%__MODULE__{} = meta, key, _value) when key == "_key", do: meta

  def add(%__MODULE__{} = meta, key, value) do
    if Tags.read_only_tag?(key) do
      meta
    else
      %{meta | data: append_value(meta.data, key, value)}
    end
  end

  @doc "Sets a metadata value, replacing any existing value. Nil removes the key."
  @spec set(t(), String.t(), String.t() | nil) :: t()
  def set(%__MODULE__{data: data} = meta, key, nil) do
    %{meta | data: Map.delete(data, key)}
  end

  def set(%__MODULE__{data: data} = meta, key, value) do
    %{meta | data: Map.put(data, key, value)}
  end

  @doc """
  Gets a metadata value by key.

  Supports indexed access: `"author.1"` returns the first author,
  `"author.-1"` returns the last.

  The special key `"_key"` computes the effective key adjusted by capo.
  """
  @spec get(t(), String.t()) :: String.t() | [String.t()] | nil
  def get(%__MODULE__{} = meta, "_key") do
    calculate_key_from_capo(meta)
  end

  def get(%__MODULE__{data: data}, key) do
    case Map.get(data, key) do
      nil -> get_array_item(data, key)
      value -> value
    end
  end

  @doc "Gets a single metadata value. If the value is a list, returns the first element."
  @spec get_single(t(), String.t()) :: String.t() | nil
  def get_single(%__MODULE__{} = meta, key) do
    case get(meta, key) do
      nil -> nil
      values when is_list(values) -> List.first(values)
      value -> value
    end
  end

  @doc "Returns all metadata including computed values."
  @spec all(t()) :: %{String.t() => String.t() | [String.t()]}
  def all(%__MODULE__{data: data} = meta) do
    case calculate_key_from_capo(meta) do
      nil -> data
      key -> Map.put(data, "_key", key)
    end
  end

  @doc "Assigns metadata from a map, merging with existing data."
  @spec assign(t(), map()) :: t()
  def assign(%__MODULE__{data: data} = meta, new_data) do
    merged =
      Enum.reduce(new_data, data, fn
        {_key, nil}, acc ->
          acc

        {"_key", _value}, acc ->
          acc

        {key, value}, acc when is_list(value) ->
          Map.put(acc, key, value)

        {key, value}, acc ->
          Map.put(acc, key, Kernel.to_string(value))
      end)

    %{meta | data: merged}
  end

  @doc "Returns a deep clone of the metadata."
  @spec clone(t()) :: t()
  def clone(%__MODULE__{data: data}) do
    cloned_data =
      Map.new(data, fn
        {k, v} when is_list(v) -> {k, Enum.map(v, & &1)}
        {k, v} -> {k, v}
      end)

    %__MODULE__{data: cloned_data}
  end

  @doc "Merges another metadata into this one."
  @spec merge(t(), t() | map()) :: t()
  def merge(%__MODULE__{} = meta, %__MODULE__{data: other_data}) do
    assign(meta, other_data)
  end

  def merge(%__MODULE__{} = meta, other_data) when is_map(other_data) do
    assign(meta, other_data)
  end

  # --- Private helpers ---

  defp append_value(data, key, value) do
    case Map.get(data, key) do
      nil -> Map.put(data, key, value)
      existing when is_list(existing) -> if value in existing, do: data, else: Map.put(data, key, existing ++ [value])
      ^value -> data
      existing -> Map.put(data, key, [existing, value])
    end
  end

  defp get_array_item(data, prop) do
    case Regex.run(~r/^(.+)\.(-?\d+)$/, prop) do
      [_, key, index_str] ->
        {index, ""} = Integer.parse(index_str)
        array_value = Map.get(data, key, [])
        array_value = if is_list(array_value), do: array_value, else: [array_value]

        idx =
          cond do
            index < 0 -> length(array_value) + index
            index > 0 -> index - 1
            true -> 0
          end

        Enum.at(array_value, idx)

      _ ->
        nil
    end
  end

  defp calculate_key_from_capo(%__MODULE__{} = meta) do
    capo_str = get_single(meta, Tags.capo())
    key_str = get_single(meta, Tags.key())

    with true <- capo_str != nil and key_str != nil,
         %Key{} = key <- Key.parse(key_str),
         {capo, ""} <- Integer.parse(capo_str) do
      key
      |> Key.transpose(capo)
      |> Key.normalize()
      |> Key.to_string()
    else
      _ -> nil
    end
  end
end

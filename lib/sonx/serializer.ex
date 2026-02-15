defmodule Sonx.Serializer do
  @moduledoc """
  Serializes and deserializes Song structs to/from maps (suitable for JSON via Jason).
  """

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Line,
    Literal,
    SoftLineBreak,
    Song,
    Tag,
    Ternary
  }

  @spec serialize(Song.t()) :: map()
  def serialize(%Song{} = song) do
    %{
      "type" => "song",
      "lines" => Enum.map(song.lines, &serialize_line/1),
      "warnings" => song.warnings
    }
  end

  @spec to_json(Song.t()) :: String.t()
  def to_json(%Song{} = song) do
    song |> serialize() |> Jason.encode!()
  end

  @spec deserialize(map()) :: {:ok, Song.t()} | {:error, term()}
  def deserialize(%{"type" => "song"} = map) do
    lines = Enum.map(Map.get(map, "lines", []), &deserialize_line/1)
    warnings = Map.get(map, "warnings", [])
    {:ok, %Song{lines: lines, warnings: warnings}}
  rescue
    e -> {:error, Exception.message(e)}
  end

  def deserialize(_), do: {:error, "invalid song map: missing type"}

  @spec from_json(String.t()) :: {:ok, Song.t()} | {:error, term()}
  def from_json(json) do
    case Jason.decode(json) do
      {:ok, map} -> deserialize(map)
      {:error, reason} -> {:error, "JSON decode error: #{inspect(reason)}"}
    end
  end

  # --- Line ---

  defp serialize_line(%Line{} = line) do
    %{
      "type" => "line",
      "items" => Enum.map(line.items, &serialize_item/1),
      "section_type" => Atom.to_string(line.type)
    }
  end

  defp deserialize_line(%{"type" => "line"} = map) do
    items = Enum.map(Map.get(map, "items", []), &deserialize_item/1)
    section_type = map |> Map.get("section_type", "none") |> String.to_existing_atom()
    %Line{items: items, type: section_type}
  end

  # --- Items ---

  defp serialize_item(%ChordLyricsPair{} = pair) do
    %{
      "type" => "chord_lyrics_pair",
      "chords" => pair.chords,
      "lyrics" => pair.lyrics,
      "annotation" => pair.annotation
    }
  end

  defp serialize_item(%Tag{} = tag) do
    %{
      "type" => "tag",
      "name" => tag.name,
      "original_name" => tag.original_name,
      "value" => tag.value,
      "attributes" => tag.attributes,
      "selector" => tag.selector,
      "is_negated" => tag.is_negated
    }
  end

  defp serialize_item(%Comment{} = comment) do
    %{
      "type" => "comment",
      "content" => comment.content
    }
  end

  defp serialize_item(%Ternary{} = ternary) do
    %{
      "type" => "ternary",
      "variable" => ternary.variable,
      "value_test" => ternary.value_test,
      "true_expression" => Enum.map(ternary.true_expression, &serialize_item/1),
      "false_expression" => Enum.map(ternary.false_expression, &serialize_item/1)
    }
  end

  defp serialize_item(%Literal{} = literal) do
    %{
      "type" => "literal",
      "string" => literal.string
    }
  end

  defp serialize_item(%SoftLineBreak{} = slb) do
    %{
      "type" => "soft_line_break",
      "content" => slb.content
    }
  end

  # --- Deserialize items ---

  defp deserialize_item(%{"type" => "chord_lyrics_pair"} = map) do
    %ChordLyricsPair{
      chords: Map.get(map, "chords", ""),
      lyrics: Map.get(map, "lyrics", ""),
      annotation: Map.get(map, "annotation")
    }
  end

  defp deserialize_item(%{"type" => "tag"} = map) do
    %Tag{
      name: Map.fetch!(map, "name"),
      original_name: Map.get(map, "original_name", Map.fetch!(map, "name")),
      value: Map.get(map, "value", ""),
      attributes: Map.get(map, "attributes", %{}),
      selector: Map.get(map, "selector"),
      is_negated: Map.get(map, "is_negated", false)
    }
  end

  defp deserialize_item(%{"type" => "comment"} = map) do
    %Comment{content: Map.get(map, "content", "")}
  end

  defp deserialize_item(%{"type" => "ternary"} = map) do
    %Ternary{
      variable: Map.get(map, "variable"),
      value_test: Map.get(map, "value_test"),
      true_expression: Enum.map(Map.get(map, "true_expression", []), &deserialize_item/1),
      false_expression: Enum.map(Map.get(map, "false_expression", []), &deserialize_item/1)
    }
  end

  defp deserialize_item(%{"type" => "literal"} = map) do
    %Literal{string: Map.get(map, "string", "")}
  end

  defp deserialize_item(%{"type" => "soft_line_break"} = map) do
    %SoftLineBreak{content: Map.get(map, "content", "")}
  end
end

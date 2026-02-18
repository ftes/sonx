defmodule Sonx.FormatterOptionsTest do
  use ExUnit.Case, async: true

  alias Sonx.FormatterOptions

  describe "validate!/1" do
    test "accepts empty opts and fills defaults" do
      result = FormatterOptions.validate!([])
      assert result[:unicode_accidentals] == false
      assert result[:normalize_chords] == false
      assert result[:evaluate] == false
      assert result[:chord_diagrams] == false
      assert result[:css_classes] == %{}
    end

    test "accepts valid opts" do
      opts = [unicode_accidentals: true, chord_diagrams: true, evaluate: true]
      result = FormatterOptions.validate!(opts)
      assert result[:unicode_accidentals] == true
      assert result[:chord_diagrams] == true
      assert result[:evaluate] == true
    end

    test "raises on unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        FormatterOptions.validate!(bogus: true)
      end
    end

    test "raises on invalid type" do
      assert_raise NimbleOptions.ValidationError, ~r/chord_diagrams/, fn ->
        FormatterOptions.validate!(chord_diagrams: "yes")
      end
    end
  end

  describe "Sonx.format/3 validates opts" do
    test "raises on unknown option" do
      {:ok, song} = Sonx.parse(:chord_pro, "[Am]Hello")

      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Sonx.format(:text, song, bogus: true)
      end
    end

    test "chord_pro raises on chord_diagrams: true" do
      {:ok, song} = Sonx.parse(:chord_pro, "[Am]Hello")

      assert_raise ArgumentError, ~r/not supported by ChordProFormatter/, fn ->
        Sonx.format(:chord_pro, song, chord_diagrams: true)
      end
    end
  end
end

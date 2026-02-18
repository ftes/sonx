defmodule Sonx.FormatterOptions do
  @moduledoc """
  NimbleOptions schema for `Sonx.format/3` options.
  """

  @schema NimbleOptions.new!(
            unicode_accidentals: [type: :boolean, default: false, doc: "Use unicode accidentals (sharp/flat)"],
            normalize_chords: [type: :boolean, default: false, doc: "Normalize chord formatting"],
            evaluate: [type: :boolean, default: false, doc: "Evaluate ternary meta expressions"],
            chord_diagrams: [
              type: :boolean,
              default: false,
              doc: "Include guitar chord diagrams (`:latex_songs` and `:typst` formatters only)"
            ],
            css_classes: [type: {:map, :atom, :string}, default: %{}, doc: "Custom CSS class map (HTML formatters)"]
          )

  @spec validate!(keyword()) :: keyword()
  def validate!(opts) do
    NimbleOptions.validate!(opts, @schema)
  end
end

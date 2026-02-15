defmodule Sonx.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/ftes/sonx"

  def project do
    [
      app: :sonx,
      name: "Sonx",
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      homepage_url: @source_url,
      source_url: @source_url,
      dialyzer: [
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt",
        plt_add_apps: [:mix]
      ]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp description do
    "Elixir library for parsing and formatting chord sheets in ChordPro, ChordsOverWords, and UltimateGuitar formats."
  end

  defp package do
    [
      licenses: ["GPL-3.0-or-later"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "notebooks/demo.livemd", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}",
      groups_for_modules: [
        "Public API": [Sonx, Sonx.Chord, Sonx.Key],
        "Chord Sheet IR": [~r/Sonx\.ChordSheet/],
        Internals: [~r/Sonx\./]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:jason, "~> 1.4"},
      {:typedstruct, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end

defmodule Sonx.MixProject do
  use Mix.Project

  def project do
    [
      app: :sonx,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt",
        plt_add_apps: [:mix]
      ]
    ]
  end

  def cli do
    [preferred_envs: [check: :test]]
  end

  defp description do
    "Elixir library for parsing and formatting chord sheets in ChordPro, ChordsOverWords, and UltimateGuitar formats."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{}
    ]
  end

  defp docs do
    [
      main: "Sonx",
      extras: ["README.md"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      check: [
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
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false}
    ]
  end
end

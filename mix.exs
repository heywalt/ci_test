defmodule HeyWalt.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [
        ignore_modules: ignore_modules(Mix.env()),
        summary: [threshold: 80]
      ],
      releases: [
        walt_ui: [
          applications: [
            marketing: :permanent,
            walt_ui: :permanent
          ]
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: ["test.coverage": :test]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "event_store.setup", "assets.setup", "assets.build"],
      "test.coverage": ["test --cover --export-coverage default", "test.coverage"]
    ]
  end

  defp ignore_modules(env) when env in [:dev, :test] do
    "./.coverignore"
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&("Elixir." <> &1))
    |> Enum.map(&String.to_atom/1)
  end

  defp ignore_modules(_env), do: []
end

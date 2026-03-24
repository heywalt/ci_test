defmodule CQRS.MixProject do
  use Mix.Project

  def project do
    [
      app: :cqrs,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:commanded, "~> 1.4"},
      {:commanded_ecto_projections, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:elixir_uuid, "~> 1.2"},
      {:jason, "~> 1.2"},
      {:repo, in_umbrella: true},
      {:typed_struct, "~> 0.3.0"}
    ]
  end

  defp aliases do
    [
      "event_store.reset": ["event_store.drop", "event_store.setup"],
      "event_store.setup": ["event_store.create", "event_store.init", "event_store.migrate"]
    ]
  end
end

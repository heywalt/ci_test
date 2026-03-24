defmodule Repo.MixProject do
  use Mix.Project

  def project do
    [
      app: :repo,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Repo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:appsignal, "~> 2.13"},
      {:ecto_hooks, "~> 1.0.1"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:scrivener_ecto, "~> 2.7"}
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

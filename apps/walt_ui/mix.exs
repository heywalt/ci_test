defmodule WaltUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :walt_ui,
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WaltUi.Application, []},
      extra_applications: [:logger, :runtime_tools] ++ maybe_observer(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp maybe_observer(env) when env in [:dev, :test], do: [:observer, :wx]
  defp maybe_observer(_), do: []

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:anubis_mcp, "~> 0.14.0"},
      {:appsignal_phoenix, "~> 2.5"},
      {:assert_async, in_umbrella: true, only: [:dev, :test]},
      {:broadway_sqs, "~> 0.7.4"},
      {:broadway_cloud_pub_sub, "~> 0.9.1"},
      {:cozy_params, "~> 2.1"},
      {:cqrs, in_umbrella: true},
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_sqs, "~> 3.4"},
      {:ex_machina, "~> 2.8", only: [:dev, :test]},
      {:ex_typesense, "~> 1.1"},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.36.0"},
      {:gcs_signed_url, "~> 0.4.6"},
      {:gettext, "~> 0.20"},
      {:gen_stage, "~> 1.2"},
      {:gen_state_machine, "~> 3.0"},
      {:goth, "~> 1.4"},
      {:google_api_pub_sub, "~> 0.36.0"},
      # for ex_aws
      {:hackney, "~> 1.20"},
      {:hammer, "~> 6.1"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:jsonapi, "~> 1.8.0"},
      {:libcluster, "~> 3.5"},
      {:nimble_csv, "~> 1.2"},
      {:mox, "~> 1.2", only: [:dev, :test]},
      {:oauth2, "~> 2.1"},
      {:oban, "~> 2.19"},
      {:oban_pro, "~> 1.5", repo: "oban"},
      {:openai, "~> 0.6.2"},
      {:phoenix, "~> 1.7.19"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0.4"},
      {:plug_cowboy, "~> 2.5"},
      {:poison, "~> 4.0"},
      {:postgrex, ">= 0.0.0"},
      {:posthog, "~> 0.4"},
      # for auth0 api
      {:prima_auth0_ex, "~> 0.7.0"},
      {:remove_emoji, "~> 1.0.0"},
      {:repo, in_umbrella: true},
      {:stripity_stripe, "~> 3.2"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:tzdata, "~> 1.1"},
      # for auth0 auth flow
      {:ua_parser, "~> 1.9"},
      {:ueberauth, "~> 0.10.7"},
      {:ueberauth_auth0, "~> 2.1"},
      {:ueberauth_google, "~> 0.12.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/walt_ui/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind app", "esbuild app"],
      "assets.deploy": ["tailwind app --minify", "esbuild app --minify", "phx.digest"]
    ]
  end
end

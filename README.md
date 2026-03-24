# WaltUi

To start your Phoenix server:

  * Run `bin/setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Go to [`localhost:4000`](http://localhost:4000) to visit the app. Or go to
[`localhost:4001`](http://localhost:4001) to visit the marketing website.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Deployments

Deployments are done via GitHub Actions. Generate a GitHub release with a tag that looks like `vYYYY.MM.DD.N`
where `N` is the release count for that day. For example, `v2025.02.26.0` would be the first release on
February 26, 2025.

## Installation

### asdf

The repo includes a `.tool-versions` file. Using `asdf`, we can install specific versions of Elixir, Erlang, and direnv
across developer machines. Just run `asdf install` from the root of this project.

### Environment variables

We use `direnv` to inject environment variables into our runtime whenever we visit this repo. The project
includes a shared `.envrc` file. This `.envrc` sources a `.envrc.private` file if it exists.

Get `.envrc.private` from the **1Password engineering vault** and place it in the project root. Then run:

```bash
source .envrc
source .envrc.private
```

Use `direnv allow .` to ensure any changes to the environment variables are injected into your runtime.

### Oban Pro

After sourcing your environment variables, run the following command to add the Oban Pro hex repo:

```bash
mix hex.repo add oban https://getoban.pro/repo --fetch-public-key SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc --auth-key $OBAN_LICENSE_KEY
```

### docker-compose

A `docker-compose.yml` file is included that sets up Postgres and a localstack version of SQS. The following
command will standup these depencencies and wait for the database to reach a healthy state before returning:

```bash
docker compose up -d  
```

### TypeSense

We use TypeSense to power search. A local version is included in our `docker-compose.yml` file, but one additional step
is required. Execute `./typesense/run.sh` to bootstrap the local TypeSense with our collection schemas.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

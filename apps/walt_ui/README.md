# WaltUi

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Deployments

Run `bin/deploy` to deploy to Fly.io. You must be on the `main` branch and have no uncommitted
or untracked files.

## Installation

### asdf

The repo includes a `.tool-versions` file. Using `asdf`, we can install specific versions of Elixir, Erlang, and direnv
across developer machines. Just run `asdf install` from the root of this project.

### Environment variables

We can use `direnv` to inject environment variables into our runtime whenver we visit this repo. The project
includes a shared `.envrc` file. This `.envrc` sources a `.envrc.private` file if it exists. Store your secrets there.

For example...

```bash
# .envrc.private
export AMAZON_ACCESS_KEY=""
export AMAZON_SECRET_KEY=""
export APPSIGNAL_PUSH_API_KEY=""
export AUTH0_API_CLIENT_SECRET=""
export AUTH0_AUTH_CLIENT_SECRET=""
export ENDATO_API_KEY=""
export FARADAY_API_KEY=""
export OPENAI_KEY=""
export STRIPE_SECRET_KEY=""
export TYPESENSE_PROD_KEY=""
```

Use `direnv allow .` to ensure any changes to the environment variables are injected into your runtime.

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

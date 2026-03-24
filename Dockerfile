# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20240130-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.16.1-erlang-26.2.1-debian-bullseye-20240130-slim
#
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=26.2.5.13
ARG DEBIAN_VERSION=bullseye-20250630-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl\
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

ARG OBAN_LICENSE_KEY
ARG POSTHOG_API_KEY
ENV MIX_ENV="prod"

ADD apps.mix.tar.gz .
COPY mix.exs mix.lock ./
COPY config/config.exs config/runtime.exs config/${MIX_ENV}.exs config/

RUN mix do local.hex --force, local.rebar --force
RUN mix hex.repo add oban https://getoban.pro/repo --fetch-public-key SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc --auth-key $OBAN_LICENSE_KEY
RUN mix do deps.get --only ${MIX_ENV}, deps.compile --skip-umbrella-children

# install node
RUN apt-get update && apt-get install -y ca-certificates curl gnupg wget
RUN mkdir -p /etc/apt/sources.list.d /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install nodejs -y
RUN wget https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.6.0/cloud-sql-proxy.linux.amd64 -O cloud_sql_proxy

COPY apps ./apps

# compile assets
RUN cd apps/walt_ui && npm install --prefix assets
RUN cd apps/marketing && npm install --prefix assets
RUN mix assets.deploy

RUN mix compile

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates build-essential procps \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/walt_ui ./
COPY --from=builder --chown=nobody:root /app/cloud_sql_proxy ./bin/

RUN mkdir -p /tmp/cloudsql
RUN chown -R nobody /app && chown -R nobody /tmp/cloudsql && chmod -R 755 /app 

USER nobody

EXPOSE 4369
EXPOSE 8080
EXPOSE 8008
EXPOSE 9998
EXPOSE 9999

CMD ["/app/bin/server"]

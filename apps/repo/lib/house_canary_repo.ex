defmodule HouseCanaryRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :repo,
    adapter: Ecto.Adapters.Postgres
end

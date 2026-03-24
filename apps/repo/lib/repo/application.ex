defmodule Repo.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [Repo, HouseCanaryRepo]
    Supervisor.start_link(children, strategy: :one_for_one, name: Repo.Supervisor)
  end
end

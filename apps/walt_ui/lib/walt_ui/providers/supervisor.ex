defmodule WaltUi.Providers.Supervisor do
  @moduledoc false

  use Supervisor

  alias WaltUi.Providers

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {DynamicSupervisor, name: Providers.GravatarSupervisor},
      {Registry, keys: :unique, name: Providers.GravatarRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

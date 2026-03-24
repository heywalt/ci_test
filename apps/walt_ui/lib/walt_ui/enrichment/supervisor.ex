defmodule WaltUi.Enrichment.Supervisor do
  @moduledoc false

  use Supervisor

  alias WaltUi.Enrichment

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Enrichment.EnrichmentRegistry},
      {Registry, keys: :unique, name: Enrichment.UnificationRegistry},
      {DynamicSupervisor, name: Enrichment.EnrichmentSupervisor},
      {DynamicSupervisor, name: Enrichment.UnificationSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

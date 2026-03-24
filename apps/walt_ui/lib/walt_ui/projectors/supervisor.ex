defmodule WaltUi.Projectors.Supervisor do
  @moduledoc false

  use Supervisor

  @projectors [
    WaltUi.Projectors.Contact,
    WaltUi.Projectors.ContactCreation,
    WaltUi.Projectors.ContactInteraction,
    WaltUi.Projectors.ContactShowcase,
    WaltUi.Projectors.Enrichment,
    WaltUi.Projectors.Faraday,
    WaltUi.Projectors.Gravatar,
    WaltUi.Projectors.Jitter,
    WaltUi.Projectors.PossibleAddress,
    WaltUi.Projectors.PttScore,
    WaltUi.Projectors.Trestle
  ]

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg,
      name: __MODULE__,
      max_restarts: Enum.count(@projectors) + 1
    )
  end

  def init(_init_arg) do
    Supervisor.init(@projectors, strategy: :one_for_one)
  end
end

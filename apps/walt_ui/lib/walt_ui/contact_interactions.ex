defmodule WaltUi.ContactInteractions do
  @moduledoc """
  The ContactInteractions context. 
  """
  import Ecto.Query, warn: false

  alias WaltUi.Projections.ContactInteraction

  @spec for_contact(Ecto.UUID.t()) :: [ContactInteraction.t()]
  def for_contact(contact_id) do
    contact_id
    |> ContactInteraction.interactions_for_contact_query()
    |> Repo.all()
  end
end

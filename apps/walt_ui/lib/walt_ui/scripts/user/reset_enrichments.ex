defmodule WaltUi.Scripts.User.ResetEnrichments do
  @moduledoc """
  Resets all enrichments for a specific user's contacts.

  This script:
  1. Finds all unique enrichment_ids for the user's contacts
  2. Sends a Reset command for each enrichment_id
  3. The Reset command will trigger projectors to clean up all related data

  Usage:
      WaltUi.Scripts.User.ResetEnrichments.run(user_id)
  """

  import Ecto.Query

  alias CQRS.Enrichments.Commands.Reset
  alias WaltUi.Projections.Contact

  @doc """
  Resets all enrichments for the specified user.

  ## Parameters
  - user_id: The UUID of the user whose enrichments should be reset

  ## Returns
  - {:ok, count} where count is the number of enrichments reset
  - {:error, reason} if there was an error
  """
  def run(user_id) do
    enrichment_ids = find_user_enrichment_ids(user_id)

    case enrichment_ids do
      [] ->
        {:ok, 0}

      ids ->
        reset_results = Enum.map(ids, &reset_enrichment/1)

        case Enum.find(reset_results, &(elem(&1, 0) == :error)) do
          nil -> {:ok, length(ids)}
          error -> error
        end
    end
  end

  defp find_user_enrichment_ids(user_id) do
    Repo.all(
      from c in Contact,
        where: c.user_id == ^user_id and not is_nil(c.enrichment_id),
        select: c.enrichment_id,
        distinct: true
    )
  end

  defp reset_enrichment(enrichment_id) do
    command = Reset.new(%{id: enrichment_id})

    case CQRS.dispatch(command) do
      :ok -> {:ok, enrichment_id}
      {:error, reason} -> {:error, reason}
    end
  end
end

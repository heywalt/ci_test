defmodule CQRS.Enrichments.Validations do
  @moduledoc """
  Shared validation functions for enrichment-related data structures.
  """

  import Ecto.Changeset

  @doc """
  Validates that provider_type is one of the supported values.
  """
  @spec validate_provider_type(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_provider_type(changeset) do
    provider_type = get_field(changeset, :provider_type)

    if provider_type in ["faraday", "trestle"] do
      changeset
    else
      add_error(changeset, :provider_type, "must be one of: faraday, trestle")
    end
  end

  @doc """
  Validates that status is either "success" or "error".
  """
  @spec validate_status(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_status(changeset) do
    status = get_field(changeset, :status)

    if status in ["success", "error"] do
      changeset
    else
      add_error(changeset, :status, "must be either: success, error")
    end
  end
end

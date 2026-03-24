defmodule WaltUi.UnifiedRecords do
  @moduledoc """
  Context functions for unified records.
  """
  import Ecto.Query

  alias WaltUi.UnifiedRecords.Contact

  @type contact_result :: {:ok, Contact.t()} | {:error, Ecto.Changeset.t()}
  @typep attrs :: map | Keyword.t()

  @spec create_contact(attrs) :: contact_result
  def create_contact(attrs) do
    attrs
    |> Map.new()
    |> Contact.changeset()
    |> Repo.insert()
  end

  @spec update_contact(Contact.t(), attrs) :: contact_result
  def update_contact(contact, attrs) do
    attrs
    |> Map.new()
    |> then(&Contact.changeset(contact, &1))
    |> Repo.update()
  end

  @spec get_contacts_by(Keyword.t()) :: [Contact.t()]
  def get_contacts_by(attrs) do
    {preloads, attrs} = Keyword.pop(attrs, :preload, [])
    Repo.all(from uni in Contact, where: ^attrs, preload: ^preloads)
  end
end

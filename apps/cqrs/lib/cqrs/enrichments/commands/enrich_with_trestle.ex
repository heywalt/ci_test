defmodule CQRS.Enrichments.Commands.EnrichWithTrestle do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :addresses, [map()], default: []
    field :age_range, String.t()
    field :emails, [String.t()], default: []
    field :first_name, String.t()
    field :last_name, String.t()
    field :phone, TenDigitPhone.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
  end

  typedstruct module: Addr do
    field :street_1, String.t(), enforce: true
    field :street_2, String.t()
    field :city, String.t()
    field :state, String.t()
    field :zip, String.t()
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset
    alias CQRS.Middleware.CommandValidation.ValidatePhone

    def certify(cmd) do
      types = %{
        id: :binary_id,
        addresses: {:array, :map},
        age_range: :string,
        emails: {:array, :string},
        first_name: :string,
        last_name: :string,
        phone: :string,
        timestamp: :naive_datetime
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :phone, :timestamp])
      |> validate_addresses()
      |> validate_emails()
      |> ValidatePhone.run()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end

    defp validate_addresses(changeset) do
      types = %{
        street_1: :string,
        street_2: :string,
        city: :string,
        state: :string,
        zip: :string
      }

      validate_change(changeset, :addresses, fn _key, addrs ->
        addrs
        |> Enum.all?(fn addr ->
          {struct(Addr), types}
          |> cast(addr, Map.keys(types))
          |> validate_required([:street_1])
          |> Map.get(:valid?)
        end)
        |> case do
          true -> []
          false -> [addresses: "invalid address in list"]
        end
      end)
    end

    defp validate_emails(changeset) do
      validate_change(changeset, :emails, fn :emails, emails ->
        emails
        |> Enum.filter(& &1)
        |> Enum.all?(fn e -> String.length(e) < 255 end)
        |> if do
          []
        else
          [emails: "an email address is too long"]
        end
      end)
    end
  end
end

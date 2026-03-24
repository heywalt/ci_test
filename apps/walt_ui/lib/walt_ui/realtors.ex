defmodule WaltUi.Realtors do
  @moduledoc """
  Manager module for realtor data operations.

  Provides functions for importing and managing realtor data, including
  CSV import with deduplication and additive phone number semantics.
  """

  import Ecto.Query

  alias NimbleCSV.RFC4180, as: CSV
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Realtors.RealtorAddress
  alias WaltUi.Realtors.RealtorAssociation
  alias WaltUi.Realtors.RealtorBrokerage
  alias WaltUi.Realtors.RealtorIdentity
  alias WaltUi.Realtors.RealtorPhoneNumber
  alias WaltUi.Realtors.RealtorRecord
  alias WaltUi.Realtors.RealtorRecordPhoneNumber

  @doc """
  Imports realtor data from a CSV file using lazy streaming.

  The CSV must have these headers (matching the standard export format):

      Email, First name, Last name, Brokerage, Address 1, Address 2,
      City, State, Zip, Cell Phone, Phone, License type, License number, Association

  The first row is treated as headers and used to build maps for each
  subsequent row. The file is streamed lazily so memory usage stays constant
  regardless of file size.

  ## Deduplication

  - Identities are deduped by email
  - Brokerages, addresses, and associations are deduped by their natural keys
  - Records are deduped by `(identity_id, content_hash)`
  - Phone numbers are deduped by `(number, type)`
  - Phone associations are additive — importing never removes existing associations
  """
  @header_mapping %{
    "Email" => :email,
    "First name" => :first_name,
    "Last name" => :last_name,
    "Brokerage" => :brokerage,
    "Address 1" => :address_1,
    "Address 2" => :address_2,
    "City" => :city,
    "State" => :state,
    "Zip" => :zip,
    "Cell Phone" => :cell_phone,
    "Phone" => :phone,
    "License type" => :license_type,
    "License number" => :license_number,
    "Association" => :association
  }

  @spec import_csv(String.t()) :: {:ok, map()} | {:error, term()}
  def import_csv(path) do
    count =
      path
      |> File.stream!()
      |> CSV.parse_stream(skip_headers: false)
      |> Stream.transform(nil, fn
        row, nil -> {[], Enum.map(row, &normalize_header/1)}
        row, headers -> {[headers |> Enum.zip(row) |> Map.new()], headers}
      end)
      |> Stream.each(&import_row/1)
      |> Enum.count()

    {:ok, %{rows_processed: count}}
  end

  defp normalize_header(header) do
    Map.get(@header_mapping, header, header)
  end

  defp import_row(row) do
    identity = find_or_create_identity(row[:email])

    brokerage_id =
      if present?(row[:brokerage]), do: find_or_create_brokerage(row[:brokerage]).id

    address_id =
      if present?(row[:address_1]) do
        find_or_create_address(
          row[:address_1],
          nilify(row[:address_2]),
          row[:city],
          row[:state],
          nilify(row[:zip])
        ).id
      end

    association_id =
      if present?(row[:association]), do: find_or_create_association(row[:association]).id

    record_attrs = %{
      realtor_identity_id: identity.id,
      first_name: nilify(row[:first_name]),
      last_name: nilify(row[:last_name]),
      license_type: nilify(row[:license_type]),
      license_number: nilify(row[:license_number]),
      brokerage_id: brokerage_id,
      address_id: address_id,
      association_id: association_id
    }

    record = find_or_create_record(record_attrs)

    if present?(row[:cell_phone]), do: link_phone_number(record.id, row[:cell_phone], "cell")
    if present?(row[:phone]), do: link_phone_number(record.id, row[:phone], "office")
  end

  # --- Identity ---

  defp find_or_create_identity(email) do
    case Repo.get_by(RealtorIdentity, email: email) do
      nil ->
        %RealtorIdentity{}
        |> RealtorIdentity.changeset(%{email: email})
        |> Repo.insert!()

      identity ->
        identity
    end
  end

  # --- Brokerage ---

  defp find_or_create_brokerage(name) do
    case Repo.get_by(RealtorBrokerage, name: name) do
      nil ->
        %RealtorBrokerage{}
        |> RealtorBrokerage.changeset(%{name: name})
        |> Repo.insert!()

      brokerage ->
        brokerage
    end
  end

  # --- Address ---

  defp find_or_create_address(address_1, address_2, city, state, zip) do
    query =
      from(a in RealtorAddress,
        where: a.address_1 == ^address_1 and a.city == ^city and a.state == ^state
      )

    query =
      if address_2 do
        from(a in query, where: a.address_2 == ^address_2)
      else
        from(a in query, where: is_nil(a.address_2))
      end

    query =
      if zip do
        from(a in query, where: a.zip == ^zip)
      else
        from(a in query, where: is_nil(a.zip))
      end

    case Repo.one(query) do
      nil ->
        %RealtorAddress{}
        |> RealtorAddress.changeset(%{
          address_1: address_1,
          address_2: address_2,
          city: city,
          state: state,
          zip: zip
        })
        |> Repo.insert!()

      address ->
        address
    end
  end

  # --- Association ---

  defp find_or_create_association(name) do
    case Repo.get_by(RealtorAssociation, name: name) do
      nil ->
        %RealtorAssociation{}
        |> RealtorAssociation.changeset(%{name: name})
        |> Repo.insert!()

      association ->
        association
    end
  end

  # --- Record ---

  defp find_or_create_record(attrs) do
    changeset = RealtorRecord.changeset(%RealtorRecord{}, attrs)
    content_hash = Ecto.Changeset.get_change(changeset, :content_hash)

    case Repo.get_by(RealtorRecord,
           realtor_identity_id: attrs.realtor_identity_id,
           content_hash: content_hash
         ) do
      nil -> Repo.insert!(changeset)
      record -> record
    end
  end

  # --- Phone Numbers ---

  defp link_phone_number(record_id, number, type) do
    phone = find_or_create_phone_number(number, type)

    if phone do
      %RealtorRecordPhoneNumber{}
      |> RealtorRecordPhoneNumber.changeset(%{
        realtor_record_id: record_id,
        realtor_phone_number_id: phone.id
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:realtor_record_id, :realtor_phone_number_id]
      )
    end
  end

  defp find_or_create_phone_number(number, type) do
    case TenDigitPhone.cast(number) do
      {:ok, normalized_number} ->
        case Repo.get_by(RealtorPhoneNumber, number: normalized_number, type: type) do
          nil ->
            %RealtorPhoneNumber{}
            |> RealtorPhoneNumber.changeset(%{number: number, type: type})
            |> Repo.insert!()

          phone ->
            phone
        end

      :error ->
        nil
    end
  end

  # --- Helpers ---

  defp present?(""), do: false
  defp present?(nil), do: false
  defp present?(_), do: true

  defp nilify(""), do: nil
  defp nilify(val), do: val
end

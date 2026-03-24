defmodule Repo.Migrations.CreateRealtorTables do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS citext")

    # Table 1: realtor_identities
    create table(:realtor_identities, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :email, :citext, null: false

      timestamps()
    end

    create unique_index(:realtor_identities, [:email])

    # Table 2: realtor_brokerages
    create table(:realtor_brokerages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :name, :citext, null: false

      timestamps()
    end

    create unique_index(:realtor_brokerages, [:name])

    # Table 3: realtor_addresses
    create table(:realtor_addresses, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :address_1, :string, null: false
      add :address_2, :string
      add :city, :string, null: false
      add :state, :string, null: false, size: 2
      add :zip, :string, size: 10

      timestamps()
    end

    execute("""
    CREATE UNIQUE INDEX realtor_addresses_compound_idx
    ON realtor_addresses (
      address_1,
      COALESCE(address_2, ''),
      city,
      state,
      COALESCE(zip, '')
    )
    """)

    # Table 4: realtor_associations
    create table(:realtor_associations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :name, :citext, null: false

      timestamps()
    end

    create unique_index(:realtor_associations, [:name])

    # Table 5: realtor_records
    create table(:realtor_records, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :first_name, :string
      add :last_name, :string
      add :license_type, :string
      add :license_number, :string
      add :content_hash, :string, null: false

      add :realtor_identity_id,
          references(:realtor_identities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :brokerage_id,
          references(:realtor_brokerages, type: :binary_id, on_delete: :nilify_all)

      add :address_id,
          references(:realtor_addresses, type: :binary_id, on_delete: :nilify_all)

      add :association_id,
          references(:realtor_associations, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:realtor_records, [:realtor_identity_id])

    create unique_index(:realtor_records, [:realtor_identity_id, :content_hash],
             name: "realtor_records_identity_content_hash_idx"
           )

    # Table 6: realtor_phone_numbers
    create table(:realtor_phone_numbers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false
      add :number, :string, null: false
      add :type, :string, null: false

      timestamps()
    end

    create unique_index(:realtor_phone_numbers, [:number, :type],
             name: "realtor_phone_numbers_number_type_idx"
           )

    # Table 7: realtor_records_phone_numbers (join table)
    create table(:realtor_records_phone_numbers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"), null: false

      add :realtor_record_id,
          references(:realtor_records, type: :binary_id, on_delete: :delete_all),
          null: false

      add :realtor_phone_number_id,
          references(:realtor_phone_numbers, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps()
    end

    create unique_index(
             :realtor_records_phone_numbers,
             [:realtor_record_id, :realtor_phone_number_id],
             name: "realtor_records_phone_numbers_unique_idx"
           )
  end

  def down do
    drop table(:realtor_records_phone_numbers)
    drop table(:realtor_phone_numbers)
    drop table(:realtor_records)
    drop table(:realtor_associations)
    drop table(:realtor_addresses)
    drop table(:realtor_brokerages)
    drop table(:realtor_identities)
    # NOTE: Intentionally NOT dropping citext extension — other tables may use it
  end
end

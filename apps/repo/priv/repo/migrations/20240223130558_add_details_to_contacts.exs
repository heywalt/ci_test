defmodule Repo.Migrations.AddDetailsToUsers do
  use Ecto.Migration

  @type_name :tshirt_size

  def change do
    execute(
      """
        CREATE TYPE #{@type_name}
          AS ENUM ('small','medium','large')
      """,
      "DROP TYPE #{@type_name}"
    )

    alter table(:contacts) do
      add :ppt, :integer
      add :has_financing, :boolean
      add :has_broker, :boolean
      add :budget_size, @type_name
      add :birthday, :date
    end
  end
end

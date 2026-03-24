defmodule WaltUi.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  def migrate do
    Application.load(:repo)

    Repo.__adapter__().storage_up(Repo.config())
    {:ok, _, _} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :up, all: true))

    HouseCanaryRepo.__adapter__().storage_up(HouseCanaryRepo.config())
    {:ok, _, _} = Ecto.Migrator.with_repo(HouseCanaryRepo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def rollback(version) do
    Application.load(:repo)
    {:ok, _, _} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :down, to: version))
  end
end

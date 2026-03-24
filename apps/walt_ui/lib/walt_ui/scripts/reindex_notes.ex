defmodule WaltUi.Scripts.ReindexNotes do
  @moduledoc false

  def run do
    WaltUi.Directory.Note
    |> Repo.all()
    |> Enum.map(&Map.from_struct/1)
    |> Enum.map(&Map.drop(&1, [:__meta__, :contact]))
    |> then(&ExTypesense.import_documents("notes", &1))
  end
end

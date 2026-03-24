defmodule WaltUi.CqrsCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Commanded.Assertions.EventAssertions
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Repo.DataCase
      import WaltUi.Helpers
    end
  end

  setup tags do
    Repo.DataCase.setup_sandbox(tags)
    setup_teardown(tags)

    :ok
  end

  @doc """
  Sets up app restart after each test to ensure CQRS starts fresh.
  """
  def setup_teardown(tags) do
    on_exit(fn ->
      unless tags[:async] do
        :ok = Application.stop(:walt_ui)
        {:ok, _} = Application.ensure_all_started(:walt_ui)
      end
    end)
  end
end

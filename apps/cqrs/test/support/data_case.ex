defmodule CQRS.DataCase do
  @moduledoc """
  ExUnit template for running tests inside the CQRS app. You probably don't want
  to use this in other apps.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Commanded.Assertions.EventAssertions
    end
  end

  setup _tags do
    Application.stop(:walt_ui)
    Application.ensure_all_started(:cqrs)

    start_supervised(CQRS)

    on_exit(fn ->
      Application.stop(:cqrs)
      Application.ensure_all_started(:walt_ui)
    end)
  end
end

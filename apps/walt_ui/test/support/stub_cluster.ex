defmodule WaltUi.StubCluster do
  @moduledoc """
  Stubs out the `Cluster.Strategy` behaviour so our cluster supervisor
  will work in the test environment.
  """
  use Cluster.Strategy

  def start_link(_state) do
    :ignore
  end
end

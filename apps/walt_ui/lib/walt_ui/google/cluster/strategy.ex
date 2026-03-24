defmodule WaltUi.Google.Cluster.Strategy do
  @moduledoc """
  Clustering strategy implementation for our GCP MIG setup.
  """
  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State
  alias WaltUi.Google

  @impl Cluster.Strategy
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    {:noreply, load(state)}
  end

  def handle_info(:load, state) do
    {:noreply, load(state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp load(%State{} = state) do
    {:ok, nodes} = Google.Cluster.get_nodes(state)

    Cluster.Strategy.connect_nodes(state.topology, state.connect, state.list_nodes, nodes)
    Process.send_after(self(), :load, 10_000)

    state
  end
end

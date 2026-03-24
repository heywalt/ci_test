defmodule WaltUi.CQRSLeader do
  @moduledoc """
  Leader election GenServer for CQRS processes.

  Only one node in the cluster runs CQRS/Commanded processes at a time.
  This prevents global registry conflicts during rolling deployments while
  maintaining exactly-once event processing guarantees.
  """

  use GenServer
  require Logger

  @leader_key {:cqrs_leader, WaltUi}
  @retry_delay 1_000
  @health_check_interval 10_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Check if this node is currently the CQRS leader"
  def leader? do
    GenServer.call(__MODULE__, :leader?)
  end

  @doc "Get the current leader node name"
  def current_leader do
    case :global.whereis_name(@leader_key) do
      :undefined -> nil
      pid -> node(pid)
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    # Monitor node connections to detect when cluster forms
    :net_kernel.monitor_nodes(true)

    # Delay initial leadership attempt to allow cluster formation
    Process.send_after(self(), :attempt_leadership, 3_000)
    schedule_health_check()
    {:ok, %{leader: false, monitor_ref: nil}}
  end

  @impl true
  def handle_call(:leader?, _from, %{leader: leader} = state) do
    {:reply, leader, state}
  end

  @impl true
  def handle_info(:attempt_leadership, state) do
    case :global.whereis_name(@leader_key) do
      :undefined -> attempt_leader_registration(state)
      pid -> handle_existing_leader(pid, state)
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{monitor_ref: ref} = state) do
    Logger.info("CQRS leader went down (#{reason}), attempting to take leadership")
    cleanup_monitor_ref(ref)
    send(self(), :attempt_leadership)
    {:noreply, %{state | monitor_ref: nil}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Ignore DOWN messages from other processes
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, _node}, state) do
    Logger.info("Node connected, checking leadership status")
    # When a new node connects, non-leaders should re-evaluate leadership
    unless state.leader do
      send(self(), :attempt_leadership)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, _node}, state) do
    Logger.info("Node disconnected, checking leadership status")
    # When a node disconnects, non-leaders should check if they can become leader
    # Leaders don't need to do anything as they're already leading
    unless state.leader do
      send(self(), :attempt_leadership)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:ensure_cqrs_running, %{leader: true} = state) do
    unless WaltUi.CQRSSupervisor.cqrs_running?() do
      Logger.warning("Leader health check: CQRS not running, starting")
      start_cqrs_processes()
    end

    schedule_health_check()
    {:noreply, state}
  end

  @impl true
  def handle_info(:ensure_cqrs_running, state) do
    schedule_health_check()
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.warning("Unexpected EXIT signal from linked process",
      pid: inspect(pid),
      reason: inspect(reason)
    )

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{leader: true}) do
    Logger.info("CQRS leader shutting down, releasing leadership")
    stop_cqrs_processes()
    :global.unregister_name(@leader_key)
    :ok
  end

  @impl true
  def terminate(_reason, %{monitor_ref: monitor_ref}) do
    cleanup_monitor_ref(monitor_ref)
    :ok
  end

  # Private Functions

  defp attempt_leader_registration(state) do
    case :global.register_name(@leader_key, self()) do
      :yes -> become_leader(state)
      :no -> retry_leadership_attempt(state)
    end
  end

  defp handle_existing_leader(pid, state) when node(pid) == node() do
    Logger.info("This node is the CQRS leader (state correction)")
    cleanup_monitor_ref(state.monitor_ref)

    # Ensure CQRS processes are running after restart with stale :global registration
    unless WaltUi.CQRSSupervisor.cqrs_running?() do
      Logger.warning("State correction detected CQRS not running, starting processes")
      start_cqrs_processes()
    end

    {:noreply, %{state | leader: true, monitor_ref: nil}}
  end

  defp handle_existing_leader(pid, state) do
    monitor_leader(pid, state)
  end

  defp become_leader(state) do
    Logger.info("This node is now CQRS leader")
    cleanup_monitor_ref(state.monitor_ref)
    start_cqrs_processes()
    {:noreply, %{state | leader: true, monitor_ref: nil}}
  end

  defp retry_leadership_attempt(state) do
    Process.send_after(self(), :attempt_leadership, @retry_delay)
    {:noreply, state}
  end

  defp monitor_leader(pid, state) do
    cleanup_monitor_ref(state.monitor_ref)
    ref = Process.monitor(pid)
    Logger.info("Another node (#{node(pid)}) is CQRS leader, monitoring...")
    {:noreply, %{state | leader: false, monitor_ref: ref}}
  end

  defp start_cqrs_processes do
    Logger.info("Starting CQRS processes as leader")
    WaltUi.CQRSSupervisor.start_cqrs_children()
  end

  defp stop_cqrs_processes do
    Logger.info("Stopping CQRS processes, stepping down as leader")
    WaltUi.CQRSSupervisor.stop_cqrs_children()
  end

  defp cleanup_monitor_ref(nil), do: :ok
  defp cleanup_monitor_ref(ref), do: Process.demonitor(ref, [:flush])

  defp schedule_health_check do
    Process.send_after(self(), :ensure_cqrs_running, @health_check_interval)
  end
end

defmodule WaltUi.CQRSSupervisor do
  @moduledoc """
  Dynamic supervisor wrapper for CQRS processes.

  This supervisor starts empty and only runs CQRS children when the node
  is elected as the CQRS leader. This prevents global registry conflicts
  during rolling deployments.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # If leader election is disabled (e.g., in tests), start CQRS immediately
    if Application.get_env(:walt_ui, :cqrs_leader_enabled, true) do
      # Start with no children - CQRSLeader will add them when this node becomes leader
      Supervisor.init([], strategy: :one_for_one)
    else
      # Start CQRS children immediately without leader election
      children = [
        CQRS,
        WaltUi.Projectors.Supervisor,
        WaltUi.Handlers.Supervisor,
        WaltUi.ProcessManagers.Supervisor
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  @doc "Start all CQRS-related children (called by CQRSLeader when becoming leader)"
  def start_cqrs_children do
    children = [
      CQRS,
      WaltUi.Projectors.Supervisor,
      WaltUi.Handlers.Supervisor,
      WaltUi.ProcessManagers.Supervisor
    ]

    Enum.each(children, fn child ->
      case Supervisor.start_child(__MODULE__, child) do
        {:ok, _pid} ->
          Logger.debug("Started CQRS child: #{inspect(child)}")

        {:error, {:already_started, _pid}} ->
          Logger.debug("CQRS child already started: #{inspect(child)}")

        {:error, reason} ->
          Logger.error("Failed to start CQRS child #{inspect(child)}: #{inspect(reason)}")
          raise "Failed to start CQRS child: #{inspect(reason)}"
      end
    end)

    Logger.info("All CQRS processes started successfully")
  end

  @doc "Stop all CQRS-related children (called by CQRSLeader when stepping down)"
  def stop_cqrs_children do
    # Get all running children
    children = Supervisor.which_children(__MODULE__)

    # Stop and delete each child
    Enum.each(children, fn {id, _pid, _type, _modules} ->
      case Supervisor.terminate_child(__MODULE__, id) do
        :ok ->
          Supervisor.delete_child(__MODULE__, id)
          Logger.debug("Stopped CQRS child: #{inspect(id)}")

        {:error, :not_found} ->
          Logger.debug("CQRS child already stopped: #{inspect(id)}")

        {:error, reason} ->
          Logger.warning("Failed to stop CQRS child #{inspect(id)}: #{inspect(reason)}")
      end
    end)

    Logger.info("All CQRS processes stopped successfully")
  end

  @doc "Check if CQRS children are currently running"
  def cqrs_running? do
    Supervisor.which_children(__MODULE__)
    |> Enum.any?(fn {_id, pid, _type, _modules} -> is_pid(pid) end)
  end
end

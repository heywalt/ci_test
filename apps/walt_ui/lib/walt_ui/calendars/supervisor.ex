defmodule WaltUi.Calendars.Supervisor do
  @moduledoc false

  use Supervisor

  alias WaltUi.Calendars

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Task.Supervisor, name: Calendars.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

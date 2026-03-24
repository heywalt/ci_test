defmodule WaltUiWeb.Api.TasksView do
  use JSONAPI.View, type: "tasks"

  def fields do
    [
      :completed_at,
      :contact_id,
      :created_by,
      :description,
      :due_at,
      :inserted_at,
      :is_complete,
      :priority,
      :remind_at,
      :updated_at
    ]
  end
end

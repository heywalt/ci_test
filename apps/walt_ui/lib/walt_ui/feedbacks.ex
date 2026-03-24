defmodule WaltUi.Feedbacks do
  @moduledoc """
  The Feedback context.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Feedbacks.Feedback

  def create_feedback(attrs \\ %{}) do
    %Feedback{}
    |> change_feedback(attrs)
    |> Repo.insert()
  end

  def change_feedback(%Feedback{} = feedback, attrs \\ %{}) do
    feedback
    |> Feedback.changeset(attrs)
  end
end

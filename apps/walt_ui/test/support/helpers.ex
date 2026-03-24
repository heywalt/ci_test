defmodule WaltUi.Helpers do
  @moduledoc """
  Helper functions for tests and REPLs.
  """
  import WaltUi.Factory

  @doc """
  Create a contact asynchronously through CQRS.

  This function uses the contact factory to fill in parameters
  left empty by the given attributes.
  """
  @spec async_contact(map) :: :ok | {:error, term}
  def async_contact(attrs \\ %{}) do
    :contact
    |> params_for(attrs)
    |> CQRS.create_contact()
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Create a batch of contacts through CQRS asynchronously.

  This function uses the contact factory to fill in parameters
  left empty by the given attributes.
  """
  @spec async_contacts(pos_integer, map) :: :ok
  def async_contacts(count, attrs \\ %{}) do
    Enum.each(1..count, fn _ -> async_contact(attrs) end)
  end

  @doc """
  Create a contact via CQRS and return the projection record.

  This function uses the contact factory to fill in parameters
  left empty by the given attributes.
  """
  @spec await_contact(map) :: WaltUi.Projections.Contact.t()
  def await_contact(attrs \\ %{}) do
    {:ok, %{id: id}} =
      :contact
      |> params_for(attrs)
      |> CQRS.create_contact(consistency: :strong)

    Repo.get(WaltUi.Projections.Contact, id)
  end

  @spec append_event(struct, Keyword.t()) :: :ok
  def append_event(event, opts \\ []) do
    data = %Commanded.EventStore.EventData{
      causation_id: Keyword.get(opts, :causation_id),
      correlation_id: Keyword.get_lazy(opts, :correlation_id, &Ecto.UUID.generate/0),
      data: event,
      event_type: to_string(event.__struct__),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    Commanded.EventStore.append_to_stream(CQRS, "$all", :any_version, [data])

    :ok
  end
end

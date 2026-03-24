defmodule WaltUi.Providers.GravatarServer do
  @moduledoc false

  use GenServer

  require Logger

  alias WaltUi.Providers
  alias WaltUi.UnifiedRecords.Contact

  @spec start_link(Contact.t(), Keyword.t()) :: GenServer.on_start()
  def start_link(%Contact{} = contact, opts) do
    name = {:via, Registry, {Providers.GravatarRegistry, contact.id}}
    {user_contact, opts} = Keyword.pop(opts, :user_contact)

    data = %{contact: contact, opts: opts, user_contact: user_contact || %{email: nil}}

    GenServer.start_link(__MODULE__, data, name: name)
  end

  @spec child_spec({Contact.t(), Keyword.t()}) :: Supervisor.child_spec()
  def child_spec({contact, opts}) do
    %{id: contact.id, start: {__MODULE__, :start_link, [contact, opts]}, restart: :transient}
  end

  @impl true
  def init(data) do
    Logger.metadata(module: __MODULE__, unified_contact_id: data.contact.id)
    {:ok, data, {:continue, :reload}}
  end

  @impl true
  def handle_continue(:reload, data) do
    case Repo.re_preload(data.contact, [:endato, :gravatar]) do
      nil ->
        Logger.warning("Unified contact deleted. Shutting down.")
        {:stop, :normal, data}

      %{endato: nil} ->
        Logger.warning("Cannot enrich with Gravatar without identity data")
        {:stop, :normal, data}

      %{gravatar: nil} = unified_contact ->
        {:noreply, %{data | contact: unified_contact}, {:continue, :gen_url}}

      _already_enriched ->
        Logger.info("Contact already has Gravatar. Shutting down.")
        {:stop, :normal, data}
    end
  end

  def handle_continue(:gen_url, data) do
    if email = data.user_contact.email || data.contact.endato.email do
      url =
        email
        |> String.trim()
        |> String.downcase()
        |> then(&:crypto.hash(:md5, &1))
        |> Base.encode16(case: :lower)
        |> then(&"https://gravatar.com/avatar/#{&1}")

      {:noreply, Map.merge(data, %{email: email, url: url}), {:continue, :check_url}}
    else
      Logger.info("No email to use for Gravatar enrichment")
      {:stop, :normal, data}
    end
  end

  def handle_continue(:check_url, data) do
    fetch_fn = Keyword.get(data.opts, :fetch_fn, &HTTPoison.get/1)

    case fetch_fn.("#{data.url}?d=404") do
      {:ok, %{status_code: code}} when code in 200..299 ->
        {:noreply, data, {:continue, :create}}

      {:ok, %{status_code: 404}} ->
        Logger.info("No Gravatar image found")
        {:stop, :normal, data}

      other ->
        Logger.warning("Unexpected response from Gravatar", details: inspect(other))
        {:stop, :normal, data}
    end
  end

  def handle_continue(:create, data) do
    attrs = %{
      email: data.email,
      url: data.url,
      unified_contact_id: data.contact.id
    }

    case Providers.create_or_update_gravatar(attrs) do
      {:ok, _} ->
        Logger.info("Enriched unified contact with Gravatar")
        {:stop, :normal, data}

      error ->
        Logger.warning("Failed to enrich unified contact with Gravatar", reason: inspect(error))
        {:stop, :normal, data}
    end
  end
end

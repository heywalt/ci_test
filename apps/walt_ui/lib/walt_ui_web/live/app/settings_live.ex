defmodule WaltUiWeb.SettingsLive do
  @moduledoc false

  use WaltUiWeb, :live_view

  alias WaltUi.Account
  alias WaltUi.Contacts
  alias WaltUi.Subscriptions

  alias Stripe.BillingPortal.Session, as: BillingPortalSession

  @column_aliases %{
    "Phone" => "phone",
    "PHONE" => "phone",
    "phone_number" => "phone",
    "Phone Number" => "phone",
    "First Name" => "first_name",
    "FirstName" => "first_name",
    "first name" => "first_name",
    "FIRST_NAME" => "first_name",
    "Last Name" => "last_name",
    "LastName" => "last_name",
    "last name" => "last_name",
    "LAST_NAME" => "last_name",
    "Email" => "email",
    "EMAIL" => "email",
    "e-mail" => "email",
    "E-mail" => "email",
    "Tags" => "tags",
    "TAGS" => "tags"
  }

  @impl true
  def mount(_params, session, socket) do
    case Account.get_session(session["session_id"]) do
      {:ok, session} ->
        {:ok, current_user} = Account.get_user_with_subscription(session.user_id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(WaltUi.PubSub, "user:#{current_user.id}")
        end

        contacts = Contacts.list_contacts_by_user(current_user.id)

        {:ok,
         socket
         |> assign(
           page_title: "Settings",
           meta_tags: %{
             title: "Settings",
             description: "Manage your account settings and subscription"
           },
           og_tags: %{},
           current_user: current_user,
           progress: 0,
           total_rows: 0,
           completed: false,
           processing: false,
           csv_valid: false,
           csv_errors: [],
           contacts: contacts,
           subscription: current_user.subscription,
           poll_until: nil
         )
         |> allow_upload(:csv,
           accept: ~w(.csv),
           max_entries: 1,
           max_file_size: 10_000_000,
           auto_upload: true
         )}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Your session has expired. Please log in again.")
         |> redirect(to: ~p"/auth/auth0")}
    end
  end

  # ============================================================================
  # Handle Events
  # ============================================================================

  @impl true
  def handle_event("manage-subscription", _params, socket) do
    case Subscriptions.get_stripe_customer_id(socket.assigns.current_user) do
      {:ok, stripe_customer_id} ->
        {:ok, session} =
          BillingPortalSession.create(%{
            customer: stripe_customer_id,
            return_url: config()[:return_url]
          })

        {:noreply, redirect(socket, external: session.url)}

      {:error, :not_found} ->
        {:noreply, push_event(socket, "show-error", %{message: "No subscription found."})}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, csv_errors: [])}
  end

  def handle_event("show-flash", %{"type" => type, "message" => message}, socket) do
    flash_type =
      case type do
        "info" -> :info
        "error" -> :error
        _ -> :info
      end

    {:noreply, put_flash(socket, flash_type, message)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("save", _params, socket) do
    lv_pid = self()

    # Validate and process in one consume pass
    results =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, entry ->
        case validate_csv_file(path) do
          {:ok, _headers} ->
            start_csv_processing(path, entry.client_name, lv_pid, socket.assigns.current_user)

          {:error, errors} ->
            {:ok, {:validation_failed, errors}}
        end
      end)

    case results do
      [{:validation_failed, errors}] ->
        {:noreply, assign(socket, csv_errors: errors)}

      _ ->
        {:noreply, assign(socket, processing: true, csv_errors: [])}
    end
  end

  # ============================================================================
  # Handle Info
  # ============================================================================

  @impl true
  def handle_info({:csv_progress, current, total}, socket) do
    {:noreply,
     socket
     |> assign(:progress, current)
     |> assign(:total_rows, total)}
  end

  def handle_info(:csv_complete, socket) do
    contacts = Contacts.list_contacts_by_user(socket.assigns.current_user.id)

    # Start polling for contact updates (CQRS creates contacts asynchronously)
    Process.send_after(self(), :refresh_contacts, 1_000)
    poll_until = System.monotonic_time(:second) + 30

    {:noreply,
     assign(socket,
       contacts: contacts,
       completed: true,
       processing: false,
       poll_until: poll_until
     )}
  end

  def handle_info(:refresh_contacts, socket) do
    contacts = Contacts.list_contacts_by_user(socket.assigns.current_user.id)
    now = System.monotonic_time(:second)

    # Keep polling if under 30 seconds
    if socket.assigns.poll_until && now < socket.assigns.poll_until do
      Process.send_after(self(), :refresh_contacts, 1_500)
    end

    {:noreply, assign(socket, contacts: contacts)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket) do
    # Task completed normally - already handled by :csv_complete
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    {:noreply,
     socket
     |> assign(processing: false)
     |> put_flash(:error, "CSV processing failed: #{inspect(reason)}")}
  end

  def handle_info({_event, sub}, socket) do
    {:noreply, update(socket, :subscription, fn _ -> sub end)}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp start_csv_processing(path, client_name, lv_pid, current_user) do
    destination_directory = Path.join(["priv", "static", "uploads"])
    dest = Path.join([destination_directory, client_name])

    File.mkdir_p!(destination_directory)
    File.cp!(path, dest)

    {:ok, task_pid} =
      Task.Supervisor.start_child(WaltUi.TaskSupervisor, fn ->
        process_csv(dest, lv_pid, current_user)
      end)

    Process.monitor(task_pid)

    {:ok, :processing}
  end

  defp validate_csv_file(path) do
    case read_and_normalize_headers(path) do
      {:ok, headers} ->
        validate_required_columns(headers)

      {:error, _reason} = error ->
        error
    end
  end

  defp read_and_normalize_headers(path) do
    case File.open(path, [:read, :utf8]) do
      {:ok, file} ->
        line = IO.read(file, :line)
        File.close(file)

        headers =
          line
          |> String.trim()
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&normalize_column_name/1)

        {:ok, headers}

      {:error, reason} ->
        {:error, ["Could not read file: #{inspect(reason)}"]}
    end
  end

  defp normalize_column_name(header) do
    Map.get(@column_aliases, header, header)
  end

  @required_columns ~w(first_name last_name email tags phone)

  defp validate_required_columns(headers) do
    missing = @required_columns -- headers

    if Enum.empty?(missing) do
      {:ok, headers}
    else
      {:error, Enum.map(missing, &"Missing required column: #{&1}")}
    end
  end

  defp process_csv(path, pid, user) do
    update_fun = fn new_acc, total_rows ->
      send(pid, {:csv_progress, new_acc, total_rows})
    end

    try do
      Contacts.create_contacts_from_csv(path, user, update_fun: update_fun)
      send(pid, :csv_complete)
    after
      File.rm(path)
    end
  end

  defp config do
    Application.get_env(:walt_ui, :stripe)
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "Please upload a CSV file"
  defp error_to_string(:too_many_files), do: "Only one file can be uploaded"
end

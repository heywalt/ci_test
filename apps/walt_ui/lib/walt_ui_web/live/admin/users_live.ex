defmodule WaltUiWeb.Admin.UsersLive do
  @moduledoc false

  use WaltUiWeb, :live_view

  alias WaltUi.Account
  alias WaltUi.Contacts

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = session["current_user"]

    user =
      id
      |> Account.get_user()
      |> Account.preload_contacts()

    socket =
      socket
      |> assign(
        page_title: "Admin: User",
        meta_tags: %{
          title: "Users",
          description: ""
        },
        og_tags: %{},
        current_user: current_user,
        user: user,
        progress: [],
        total_rows: 0,
        completed: false
      )
      |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 10_000_000)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show-flash", %{"type" => type, "message" => message}, socket) do
    flash_type =
      case type do
        "info" -> :info
        "error" -> :error
        _ -> :info
      end

    {:noreply, put_flash(socket, flash_type, message)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("save", _params, socket) do
    lv_pid = self()

    consume_uploaded_entries(socket, :csv, fn %{path: path}, entry ->
      destination_directory = Path.join(["priv", "static", "uploads"])
      dest = Path.join([destination_directory, entry.client_name])

      File.mkdir_p!(destination_directory)
      File.cp!(path, dest)

      Task.start(fn ->
        process_csv(dest, lv_pid, socket.assigns.user)
      end)

      {:ok, "/uploads/#{Path.basename(dest)}"}
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:csv_progress, current, total}, socket) do
    {:noreply,
     socket
     |> assign(:progress, current)
     |> assign(:total_rows, total)}
  end

  @impl true
  def handle_info(:csv_complete, socket) do
    {:noreply, assign(socket, :completed, true)}
  end

  defp process_csv(path, pid, user) do
    update_fun = fn new_acc, total_rows ->
      send(pid, {:csv_progress, new_acc, total_rows})
    end

    Contacts.create_contacts_from_csv(path, user, update_fun: update_fun)

    # Clean up and signal completion
    File.rm!(path)
    send(pid, :csv_complete)
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "Please upload a CSV file"
  defp error_to_string(:too_many_files), do: "Only one file can be uploaded"
end

defmodule WaltUiWeb.AdminComponents do
  @moduledoc """
  Admin-specific UI components for displaying data in the admin interface.
  """
  use Phoenix.Component

  @doc """
  Displays provider data in a collapsible, formatted view.

  ## Attributes
  - provider_data: The provider data struct to display
  - provider_name: Name of the provider (e.g., "Endato", "Faraday")
  - class: Additional CSS classes for the summary element
  - max_height: Maximum height CSS class for scrollable content (default: "max-h-64")
  - field_width: Minimum width CSS class for field labels (default: "min-w-[140px]")
  """
  attr :provider_data, :map, required: true
  attr :provider_name, :string, required: true
  attr :class, :string, default: ""
  attr :max_height, :string, default: "max-h-64"
  attr :field_width, :string, default: "min-w-[140px]"

  def provider_data_display(assigns) do
    ~H"""
    <%= if @provider_data do %>
      <details>
        <summary class={"cursor-pointer text-sm font-medium text-gray-600 hover:text-gray-800 mb-2 #{@class}"}>
          View {@provider_name} Data
        </summary>
        <div class="provider-data-content mt-2">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-1 text-xs">
            <%= for {field_name, {type, value}} <- format_provider_data(@provider_data) do %>
              <div class="flex break-inside-avoid">
                <span class="font-medium text-gray-600 min-w-[120px] flex-shrink-0">{field_name}:</span>
                <span class="text-gray-800 flex-1">
                  <%= case type do %>
                    <% :boolean -> %>
                      {if value, do: "Yes", else: "No"}
                    <% :datetime -> %>
                      {value}
                    <% :list -> %>
                      <div class="ml-2">
                        <%= for item <- value do %>
                          <div>• {item}</div>
                        <% end %>
                      </div>
                    <% :list_of_maps -> %>
                      <div class="ml-2 space-y-1">
                        <%= for map <- value do %>
                          <div class="border-l-2 border-gray-200 pl-2">
                            <%= for {k, v} <- map do %>
                              <div>{k}: {v}</div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% _ -> %>
                      {value}
                  <% end %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </details>
    <% end %>
    """
  end

  @doc """
  Compact variant of provider_data_display for smaller display areas.
  """
  attr :provider_data, :map, required: true
  attr :provider_name, :string, required: true

  def provider_data_display_compact(assigns) do
    ~H"""
    <%= if @provider_data do %>
      <details>
        <summary class="cursor-pointer text-xs text-gray-600">View Data</summary>
        <div class="provider-data-content mt-1">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-1 text-xs">
            <%= for {field_name, {type, value}} <- format_provider_data(@provider_data) do %>
              <div class="flex break-inside-avoid">
                <span class="font-medium text-gray-600 min-w-[100px] flex-shrink-0 text-xs">{field_name}:</span>
                <span class="text-gray-800 text-xs flex-1">
                  <%= case type do %>
                    <% :boolean -> %>
                      {if value, do: "Yes", else: "No"}
                    <% :datetime -> %>
                      {value}
                    <% :list -> %>
                      {Enum.join(value, ", ")}
                    <% :list_of_maps -> %>
                      <div class="ml-1">
                        <%= for map <- value do %>
                          <div class="border-l border-gray-200 pl-1">
                            <%= for {k, v} <- map do %>
                              <div>{k}: {v}</div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% _ -> %>
                      {value}
                  <% end %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </details>
    <% end %>
    """
  end

  # Helper function to format provider data for display
  def format_provider_data(nil), do: []

  def format_provider_data(provider_data) do
    provider_data
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__, :id])
    |> Enum.reject(fn {_k, v} -> is_nil(v) || v == [] || v == "" end)
    |> Enum.map(fn {key, value} ->
      {format_field_name(key), format_field_value(value)}
    end)
    |> Enum.sort_by(fn {key, _} -> key end)
  end

  defp format_field_name(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_field_value(%DateTime{} = dt) do
    {:datetime, Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")}
  end

  defp format_field_value(%NaiveDateTime{} = dt) do
    {:datetime, Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")}
  end

  defp format_field_value(value) when is_list(value) do
    if Enum.all?(value, &is_struct/1) do
      # List of embedded schemas (addresses)
      {:list_of_maps, Enum.map(value, &format_embedded_struct/1)}
    else
      # Regular list of strings/primitives
      {:list, value}
    end
  end

  defp format_field_value(value) when is_boolean(value) do
    {:boolean, value}
  end

  defp format_field_value(value) when is_number(value) do
    {:text, to_string(value)}
  end

  defp format_field_value(value) do
    {:text, to_string(value)}
  end

  defp format_embedded_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__, :id])
    |> Enum.reject(fn {_k, v} -> is_nil(v) || v == "" end)
    |> Enum.map(fn {k, v} -> {format_field_name(k), v} end)
    |> Enum.into(%{})
  end
end

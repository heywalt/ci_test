defmodule CQRS.Utils do
  @moduledoc """
  Helper functions.
  """

  @doc """
  A safe function for converting string to atoms. If the value is already an
  atom, just return it.
  """
  @spec string_to_atom(term) :: atom | term
  def string_to_atom(value) when is_binary(value), do: String.to_atom(value)
  def string_to_atom(value), do: value

  @doc """
  A safe function for converting a map with string keys into a map with atom keys.
  If the map already has atom keys, just return it.
  """
  @spec atom_map(map) :: map
  def atom_map(%Decimal{} = decimal), do: decimal

  def atom_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {string_to_atom(k), atom_map(v)} end)
    |> Enum.into(%{})
  end

  def atom_map(list) when is_list(list) do
    list |> Enum.map(&atom_map/1)
  end

  def atom_map(value), do: value

  @doc """
  Gets a value from a map by trying both atom and string versions of the key.

  Tries the atom key first, then falls back to the string version.
  Returns the default value if neither key exists.

  ## Examples

      iex> Utils.get(%{name: "John"}, :name)
      "John"

      iex> Utils.get(%{"name" => "John"}, :name)
      "John"

      iex> Utils.get(%{}, :name, "Unknown")
      "Unknown"
  """
  @spec get(map, atom, default) :: any | default when default: any
  def get(map, atom_key, default \\ nil) when is_atom(atom_key) do
    string_key = to_string(atom_key)
    Map.get(map, atom_key, Map.get(map, string_key, default))
  end
end

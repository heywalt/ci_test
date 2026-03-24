defmodule Repo.Types.TenDigitPhone do
  @moduledoc """
  An `Ecto.Type` implementation to convert phone numbers into a 10-digit string.
  """
  @behaviour Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(value) when is_binary(value) do
    value
    |> format()
    |> validate_length()
  end

  def cast(value) do
    value
    |> to_string()
    |> cast()
  rescue
    _ -> :error
  end

  @impl true
  def dump(value) when is_binary(value) do
    {:ok, value}
  end

  def dump(_value), do: :error

  @impl true
  def load(value) when is_binary(value) do
    {:ok, format(value)}
  end

  @impl true
  def equal?(one, two) when is_binary(one) and is_binary(two) do
    format(one) == format(two)
  end

  def equal?(one, two) do
    one = to_string(one)
    two = to_string(two)
    equal?(one, two)
  rescue
    _ -> false
  end

  @impl true
  def embed_as(_field), do: :dump

  defp format(value) do
    value
    |> String.replace("+1", "")
    |> String.replace(~r/[^0-9]/, "")
    |> maybe_remove_first_digit()
  end

  defp maybe_remove_first_digit(value) do
    if String.length(value) > 10 do
      String.slice(value, 1..-1//1)
    else
      value
    end
  end

  defp validate_length(value) do
    case String.length(value) do
      10 -> {:ok, value}
      _ -> :error
    end
  end
end

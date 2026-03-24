defmodule Repo.WaltSchema do
  @moduledoc """
  Schema module that defines a macro that enforces UUID primary keys and foreign keys for all
  schemas in the application.

  This works by defining a `__using__/1` macro that injects the necessary attributes into the
  schema module that uses it.

  This means that, instead of using `use Ecto.Schema`, which is what you might see in an
  Elixir/Phoenix sample project, or example, in your schema modules, you should use
  `use Repo.WaltSchema` instead.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      alias Repo.Types.TenDigitPhone

      @primary_key {:id, Ecto.UUID, autogenerate: true}
      @foreign_key_type Ecto.UUID
    end
  end
end

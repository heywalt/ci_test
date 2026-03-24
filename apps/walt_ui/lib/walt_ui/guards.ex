defmodule WaltUi.Guards do
  @moduledoc """
  A collection of custom Elixir guards. To use, import this module.

      defmodule WaltUi.MyModule do
        import WaltUi.Guards

        # ...
      end
  """
  import :erlang, only: [map_get: 2]

  defguard is_premium_user(data)
           when map_get(:__struct__, data) == WaltUi.Account.User and
                  map_get(:tier, data) == :premium
end

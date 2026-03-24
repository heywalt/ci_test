defmodule AssertAsync do
  @moduledoc """
  Helper macro for making assertions on async actions. Especially useful for testing processes
  like `GenServer` and `GenStateMachine` implementations.

  ## Usage

  Import the module and use the `assert_async/2` macro:

      import AssertAsync

      assert_async do
        assert async_thing()
      end

  ## Options

  * `debug`: Boolean to produce `DEBUG` messages on failing iterations. Defaults to false.
  * `max_tries`: Number of attempts to make before failing assertion. Defaults to 10.
  * `sleep`: Time in milliseonds to wait between attempts. Defaults to 100.
  """

  defmodule Private do
    @moduledoc false

    require Logger

    @defaults %{debug: false, max_tries: 10, sleep: 100}
    @errors [ExUnit.AssertionError, Mimic.VerificationError]

    def assert(fun, opts) do
      opts = Map.merge(@defaults, Map.new(opts))
      do_assert(fun, opts)
    end

    defp do_assert(fun, %{max_tries: 1}), do: fun.()

    defp do_assert(fun, opts) do
      fun.()
    rescue
      e in @errors ->
        if opts.debug do
          Logger.debug(fn -> e.message end)
        end

        :timer.sleep(opts.sleep)
        do_assert(fun, %{opts | max_tries: opts.max_tries - 1})
    end
  end

  defmacro assert_async(opts \\ [], do: do_block) do
    quote do
      AssertAsync.Private.assert(fn -> unquote(do_block) end, unquote(opts))
    end
  end
end

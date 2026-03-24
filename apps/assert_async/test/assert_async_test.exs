defmodule AssertAsyncTest do
  use ExUnit.Case, async: true

  import AssertAsync

  describe "assert_async/2" do
    test "iterates until assertion passes" do
      {:ok, pid} = Agent.start(fn -> 0 end)
      self = self()

      assert_async do
        n = Agent.get_and_update(pid, &{&1, &1 + 1})
        send(self, n)
        assert n == 3
      end

      assert_receive 1
      assert_receive 2
      assert_receive 3
      refute_receive 4
    end

    test "fails test eventually" do
      assert_raise ExUnit.AssertionError, fn ->
        assert_async do
          assert false
        end
      end
    end

    test "allows exception through retries" do
      {:ok, pid} = Agent.start(fn -> 0 end)

      assert_raise RuntimeError, fn ->
        assert_async do
          Agent.update(pid, &(&1 + 1))
          raise "exception"
        end
      end

      assert Agent.get(pid, & &1) == 1
    end
  end
end

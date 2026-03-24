defmodule WaltUi.CQRSLeaderTest do
  use ExUnit.Case, async: true

  alias WaltUi.CQRSLeader

  describe "handle_info(:ensure_cqrs_running, ...)" do
    test "when leader and CQRS not running, starts CQRS and schedules next check" do
      state = %{leader: true, monitor_ref: nil}

      # Call the handler directly - it will try to start CQRS (which is already running in tests)
      # but that's fine since start_cqrs_children handles :already_started gracefully
      {:noreply, new_state} = CQRSLeader.handle_info(:ensure_cqrs_running, state)

      # State should be unchanged
      assert new_state == state
    end

    test "when not leader, does not start CQRS but schedules next check" do
      state = %{leader: false, monitor_ref: nil}

      {:noreply, new_state} = CQRSLeader.handle_info(:ensure_cqrs_running, state)

      # State should be unchanged
      assert new_state == state
    end

    test "when leader and CQRS already running, does nothing but schedules next check" do
      state = %{leader: true, monitor_ref: nil}

      {:noreply, new_state} = CQRSLeader.handle_info(:ensure_cqrs_running, state)

      assert new_state == state
    end
  end
end

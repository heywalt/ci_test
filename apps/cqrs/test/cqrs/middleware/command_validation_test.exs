defmodule CQRS.Middleware.CommandValidationTest do
  use ExUnit.Case, async: true

  alias Commanded.Middleware.Pipeline
  alias CQRS.Leads.Commands
  alias CQRS.Middleware.CommandValidation

  describe "before_dispatch/1" do
    test "returns pipeline if validation passes" do
      cmd = %Commands.Delete{id: UUID.uuid4()}
      pipeline = %Pipeline{causation_id: UUID.uuid4(), command: cmd}

      assert CommandValidation.before_dispatch(pipeline) == pipeline
    end

    test "halts pipeline if validation fails" do
      cmd = %Commands.Create{
        id: UUID.uuid4(),
        phone: "8005551234",
        timestamp: NaiveDateTime.utc_now(),
        user_id: UUID.uuid4()
      }

      input = %Pipeline{causation_id: UUID.uuid4(), command: cmd}
      refute input.halted

      output = CommandValidation.before_dispatch(input)
      assert output.causation_id == input.causation_id
      assert output.halted
    end
  end

  describe "after_dispatch/1" do
    test "passes pipeline through" do
      pipeline = %Pipeline{causation_id: UUID.uuid4()}
      assert CommandValidation.after_dispatch(pipeline) == pipeline
    end
  end

  describe "after_failure/1" do
    test "passes pipeline through" do
      pipeline = %Pipeline{causation_id: UUID.uuid4()}
      assert CommandValidation.after_failure(pipeline) == pipeline
    end
  end
end

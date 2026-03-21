defmodule Agents.Pipeline.Domain.Entities.StageResultTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.StageResult

  test "round-trips to and from persisted maps" do
    result =
      StageResult.new(%{
        stage_id: "verification",
        status: :failed,
        output: "boom",
        exit_code: 1,
        failure_reason: "non_zero_exit"
      })

    persisted = StageResult.to_map(result)
    restored = StageResult.from_map(persisted)

    assert restored.stage_id == "verification"
    assert restored.status == :failed
    assert restored.failure_reason == "non_zero_exit"
  end
end

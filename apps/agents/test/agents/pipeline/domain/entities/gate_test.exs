defmodule Agents.Pipeline.Domain.Entities.GateTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Gate

  test "new/1 defaults required to true" do
    gate = Gate.new(%{type: "approval"})

    assert gate.type == "approval"
    assert gate.required
    assert gate.params == %{}
  end
end

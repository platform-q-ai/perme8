defmodule Agents.Pipeline.Domain.Entities.GateTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Gate

  test "new/1 defaults required to true" do
    gate = Gate.new(%{type: "approval"})

    assert gate.type == "approval"
    assert gate.required
    assert gate.params == %{}
  end

  test "new/1 keeps gate params for runtime evaluation" do
    gate = Gate.new(%{type: "manual_approval", params: %{"key" => "merge-window"}})

    assert gate.type == "manual_approval"
    assert gate.params["key"] == "merge-window"
  end
end

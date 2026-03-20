defmodule Agents.Pipeline.Domain.Entities.StepTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Step

  test "new/1 applies defaults for retries and env" do
    step = Step.new(%{name: "compile", run: "mix compile"})

    assert step.name == "compile"
    assert step.run == "mix compile"
    assert step.retries == 0
    assert step.env == %{}
  end
end

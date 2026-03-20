defmodule Agents.Pipeline.Domain.Entities.DeployTargetTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.DeployTarget

  test "new/1 defaults strategy and config" do
    target =
      DeployTarget.new(%{id: "prod", environment: "production", provider: "fly"})

    assert target.id == "prod"
    assert target.environment == "production"
    assert target.provider == "fly"
    assert target.strategy == "rolling"
    assert target.config == %{}
  end
end

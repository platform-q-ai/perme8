defmodule Agents.Pipeline.Domain.Entities.DeployTargetTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.DeployTarget

  describe "new/1" do
    test "creates a DeployTarget struct" do
      target = DeployTarget.new(%{name: "production", type: "render"})

      assert %DeployTarget{} = target
      assert target.name == "production"
      assert target.type == "render"
    end

    test "sets defaults" do
      target = DeployTarget.new(%{name: "staging", type: "render"})

      assert target.auto_deploy == false
      assert target.config == %{}
    end

    test "accepts all fields" do
      target =
        DeployTarget.new(%{
          name: "production",
          type: "render",
          auto_deploy: true,
          config: %{"service_id" => "srv-123", "region" => "oregon"}
        })

      assert target.name == "production"
      assert target.type == "render"
      assert target.auto_deploy == true
      assert target.config == %{"service_id" => "srv-123", "region" => "oregon"}
    end
  end

  describe "render?/1" do
    test "returns true for render type" do
      target = DeployTarget.new(%{name: "prod", type: "render"})

      assert DeployTarget.render?(target) == true
    end

    test "returns false for k3s type" do
      target = DeployTarget.new(%{name: "staging", type: "k3s"})

      assert DeployTarget.render?(target) == false
    end
  end

  describe "auto_deploy?/1" do
    test "returns true when auto_deploy is true" do
      target = DeployTarget.new(%{name: "prod", type: "render", auto_deploy: true})

      assert DeployTarget.auto_deploy?(target) == true
    end

    test "returns false when auto_deploy is false" do
      target = DeployTarget.new(%{name: "prod", type: "render"})

      assert DeployTarget.auto_deploy?(target) == false
    end
  end
end

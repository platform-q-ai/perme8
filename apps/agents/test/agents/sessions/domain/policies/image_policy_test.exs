defmodule Agents.Sessions.Domain.Policies.ImagePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.ImagePolicy

  describe "light_image?/1" do
    test "returns true for perme8-opencode-light" do
      assert ImagePolicy.light_image?("perme8-opencode-light")
    end

    test "returns false for perme8-opencode" do
      refute ImagePolicy.light_image?("perme8-opencode")
    end

    test "returns false for perme8-pi" do
      refute ImagePolicy.light_image?("perme8-pi")
    end

    test "returns false for nil" do
      refute ImagePolicy.light_image?(nil)
    end
  end

  describe "bypasses_queue?/1" do
    test "returns true for light images" do
      assert ImagePolicy.bypasses_queue?("perme8-opencode-light")
    end

    test "returns false for non-light images" do
      refute ImagePolicy.bypasses_queue?("perme8-opencode")
    end
  end

  describe "resource_limits/1" do
    test "returns reduced limits for light images" do
      assert ImagePolicy.resource_limits("perme8-opencode-light") == %{memory: "512m", cpus: "1"}
    end

    test "returns default limits for standard images" do
      assert ImagePolicy.resource_limits("perme8-opencode") == %{memory: "2g", cpus: "2"}
    end

    test "returns default limits for nil" do
      assert ImagePolicy.resource_limits(nil) == %{memory: "2g", cpus: "2"}
    end
  end

  describe "light_image_names/0" do
    test "returns list containing perme8-opencode-light" do
      assert "perme8-opencode-light" in ImagePolicy.light_image_names()
    end
  end
end

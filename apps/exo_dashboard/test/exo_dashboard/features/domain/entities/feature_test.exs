defmodule ExoDashboard.Features.Domain.Entities.FeatureTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Domain.Entities.Feature

  describe "new/1" do
    test "creates a feature with all fields from keyword list" do
      feature =
        Feature.new(
          id: "feat-1",
          uri: "apps/jarga_web/test/features/login.browser.feature",
          name: "User Login",
          description: "Login flow for users",
          tags: ["@smoke"],
          app: "jarga_web",
          adapter: :browser,
          language: "en",
          children: [:scenario_placeholder]
        )

      assert feature.id == "feat-1"
      assert feature.uri == "apps/jarga_web/test/features/login.browser.feature"
      assert feature.name == "User Login"
      assert feature.description == "Login flow for users"
      assert feature.tags == ["@smoke"]
      assert feature.app == "jarga_web"
      assert feature.adapter == :browser
      assert feature.language == "en"
      assert feature.children == [:scenario_placeholder]
    end

    test "defaults children to empty list" do
      feature = Feature.new(name: "Minimal Feature")
      assert feature.children == []
    end

    test "defaults tags to empty list" do
      feature = Feature.new(name: "No Tags")
      assert feature.tags == []
    end

    test "creates a feature from a map" do
      feature = Feature.new(%{name: "From Map", uri: "test.feature"})
      assert feature.name == "From Map"
      assert feature.uri == "test.feature"
    end
  end
end

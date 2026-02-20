defmodule ExoDashboard.TestRuns.Domain.Policies.ResultMatcherTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.TestRuns.Domain.Policies.ResultMatcher
  alias ExoDashboard.Features.Domain.Entities.Feature
  alias ExoDashboard.Features.Domain.Entities.Scenario

  describe "match_pickle_to_feature/2" do
    test "maps a pickle to its feature and scenario by URI and astNodeIds" do
      scenario = Scenario.new(id: "scenario-1", name: "User logs in")

      features = [
        Feature.new(
          uri: "apps/jarga_web/test/features/login.browser.feature",
          name: "Login",
          children: [scenario]
        )
      ]

      pickle = %{
        "uri" => "apps/jarga_web/test/features/login.browser.feature",
        "astNodeIds" => ["scenario-1"]
      }

      result = ResultMatcher.match_pickle_to_feature(pickle, features)

      assert result == %{
               feature_uri: "apps/jarga_web/test/features/login.browser.feature",
               scenario_name: "User logs in"
             }
    end

    test "returns nil when no feature matches the pickle URI" do
      features = [
        Feature.new(uri: "other.feature", name: "Other", children: [])
      ]

      pickle = %{
        "uri" => "nonexistent.feature",
        "astNodeIds" => ["scenario-1"]
      }

      assert ResultMatcher.match_pickle_to_feature(pickle, features) == nil
    end

    test "returns nil when no scenario matches the astNodeIds" do
      scenario = Scenario.new(id: "scenario-99", name: "Other scenario")

      features = [
        Feature.new(uri: "login.feature", name: "Login", children: [scenario])
      ]

      pickle = %{
        "uri" => "login.feature",
        "astNodeIds" => ["nonexistent-id"]
      }

      assert ResultMatcher.match_pickle_to_feature(pickle, features) == nil
    end

    test "handles features with no children" do
      features = [Feature.new(uri: "empty.feature", name: "Empty")]
      pickle = %{"uri" => "empty.feature", "astNodeIds" => ["s-1"]}

      assert ResultMatcher.match_pickle_to_feature(pickle, features) == nil
    end
  end

  describe "match_test_step_to_pickle_step/3" do
    test "maps a test step via pickleStepId to the pickle step" do
      pickle_steps = [
        %{"id" => "ps-1", "text" => "the user is on the login page"},
        %{"id" => "ps-2", "text" => "they enter valid credentials"}
      ]

      test_step = %{"pickleStepId" => "ps-2"}

      result = ResultMatcher.match_test_step_to_pickle_step(test_step, pickle_steps)

      assert result == %{"id" => "ps-2", "text" => "they enter valid credentials"}
    end

    test "returns nil when no pickle step matches" do
      pickle_steps = [%{"id" => "ps-1", "text" => "some step"}]
      test_step = %{"pickleStepId" => "nonexistent"}

      assert ResultMatcher.match_test_step_to_pickle_step(test_step, pickle_steps) == nil
    end

    test "returns nil when pickle_steps is empty" do
      test_step = %{"pickleStepId" => "ps-1"}

      assert ResultMatcher.match_test_step_to_pickle_step(test_step, []) == nil
    end
  end
end

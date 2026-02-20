defmodule ExoDashboard.Features.Domain.Entities.StepTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Domain.Entities.Step

  describe "new/1" do
    test "creates a step with all fields" do
      step =
        Step.new(
          id: "step-1",
          keyword: "Given ",
          keyword_type: "Context",
          text: "the user is on the login page",
          location: %{line: 10, column: 5},
          data_table: nil,
          doc_string: nil
        )

      assert step.id == "step-1"
      assert step.keyword == "Given "
      assert step.keyword_type == "Context"
      assert step.text == "the user is on the login page"
      assert step.location == %{line: 10, column: 5}
      assert step.data_table == nil
      assert step.doc_string == nil
    end

    test "creates a step with data_table" do
      table = [["username", "password"], ["admin", "secret"]]
      step = Step.new(keyword: "When ", text: "I fill in", data_table: table)
      assert step.data_table == table
    end

    test "creates a step with doc_string" do
      doc = %{content: "some text", media_type: "text/plain"}
      step = Step.new(keyword: "Then ", text: "I should see", doc_string: doc)
      assert step.doc_string == doc
    end

    test "creates from map" do
      step = Step.new(%{keyword: "And ", text: "something happens"})
      assert step.keyword == "And "
      assert step.text == "something happens"
    end
  end
end

defmodule Agents.Pipeline.Infrastructure.Schemas.PullRequestSchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Infrastructure.Schemas.PullRequestSchema

  describe "changeset/2" do
    test "requires source/target/title" do
      changeset = PullRequestSchema.changeset(%PullRequestSchema{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).source_branch
      assert "can't be blank" in errors_on(changeset).target_branch
      assert "can't be blank" in errors_on(changeset).title
    end

    test "validates status inclusion" do
      changeset =
        PullRequestSchema.changeset(%PullRequestSchema{}, %{
          source_branch: "feature/a",
          target_branch: "main",
          title: "Test",
          status: "invalid"
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end
  end
end

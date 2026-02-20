defmodule Agents.Sessions.Infrastructure.Schemas.TaskSchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  @valid_attrs %{
    instruction: "Write tests for the login flow",
    user_id: nil
  }

  setup do
    user = user_fixture()
    {:ok, user: user, valid_attrs: Map.put(@valid_attrs, :user_id, user.id)}
  end

  describe "changeset/2" do
    test "valid changeset with all required fields", %{valid_attrs: attrs} do
      changeset = TaskSchema.changeset(%TaskSchema{}, attrs)
      assert changeset.valid?
    end

    test "requires instruction", %{user: user} do
      changeset = TaskSchema.changeset(%TaskSchema{}, %{user_id: user.id})
      refute changeset.valid?
      assert %{instruction: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires user_id" do
      changeset = TaskSchema.changeset(%TaskSchema{}, %{instruction: "Do something"})
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status is one of valid statuses", %{valid_attrs: attrs} do
      changeset = TaskSchema.changeset(%TaskSchema{}, Map.put(attrs, :status, "invalid"))
      refute changeset.valid?
      assert %{status: _} = errors_on(changeset)
    end

    test "defaults status to pending", %{valid_attrs: attrs} do
      changeset = TaskSchema.changeset(%TaskSchema{}, attrs)
      assert changeset.valid?
      # The default comes from the schema definition, not the changeset
      task = %TaskSchema{}
      assert task.status == "pending"
    end

    test "accepts optional fields", %{valid_attrs: attrs} do
      attrs_with_optional =
        Map.merge(attrs, %{
          container_id: "abc123",
          container_port: 4096,
          session_id: "sess-123",
          error: "something went wrong",
          started_at: ~U[2026-01-01 00:00:00.000000Z],
          completed_at: ~U[2026-01-02 00:00:00.000000Z]
        })

      changeset = TaskSchema.changeset(%TaskSchema{}, attrs_with_optional)
      assert changeset.valid?
    end
  end

  describe "status_changeset/2" do
    test "allows updating status", %{valid_attrs: attrs} do
      {:ok, task} = %TaskSchema{} |> TaskSchema.changeset(attrs) |> Repo.insert()

      changeset = TaskSchema.status_changeset(task, %{status: "starting"})
      assert changeset.valid?
    end

    test "allows updating container fields", %{valid_attrs: attrs} do
      {:ok, task} = %TaskSchema{} |> TaskSchema.changeset(attrs) |> Repo.insert()

      changeset =
        TaskSchema.status_changeset(task, %{
          status: "starting",
          container_id: "container-abc",
          container_port: 4096,
          session_id: "sess-123"
        })

      assert changeset.valid?
    end

    test "allows updating error and timestamps", %{valid_attrs: attrs} do
      {:ok, task} = %TaskSchema{} |> TaskSchema.changeset(attrs) |> Repo.insert()

      changeset =
        TaskSchema.status_changeset(task, %{
          status: "failed",
          error: "Container crashed",
          started_at: ~U[2026-01-01 00:00:00.000000Z],
          completed_at: ~U[2026-01-01 01:00:00.000000Z]
        })

      assert changeset.valid?
    end

    test "validates status is valid", %{valid_attrs: attrs} do
      {:ok, task} = %TaskSchema{} |> TaskSchema.changeset(attrs) |> Repo.insert()

      changeset = TaskSchema.status_changeset(task, %{status: "bogus"})
      refute changeset.valid?
    end

    test "does not allow updating instruction", %{valid_attrs: attrs} do
      {:ok, task} = %TaskSchema{} |> TaskSchema.changeset(attrs) |> Repo.insert()

      changeset =
        TaskSchema.status_changeset(task, %{
          status: "running",
          instruction: "Hacked instruction"
        })

      # instruction should not be in the changes
      refute Map.has_key?(changeset.changes, :instruction)
    end
  end
end

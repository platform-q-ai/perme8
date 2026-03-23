defmodule Agents.Sessions.Infrastructure.Schemas.SessionSchemaTest do
  use Agents.DataCase, async: false

  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema

  @valid_attrs %{
    user_id: Ecto.UUID.generate()
  }

  describe "changeset/2" do
    test "creates valid changeset with required fields" do
      changeset = SessionSchema.changeset(%SessionSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = SessionSchema.changeset(%SessionSchema{}, %{})
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "sets default status to active" do
      changeset = SessionSchema.changeset(%SessionSchema{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "active"
    end

    test "sets default container_status to pending" do
      changeset = SessionSchema.changeset(%SessionSchema{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :container_status) == "pending"
    end

    test "sets default image" do
      changeset = SessionSchema.changeset(%SessionSchema{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :image) == "perme8-opencode"
    end

    test "validates status inclusion" do
      attrs = Map.put(@valid_attrs, :status, "invalid")
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "validates container_status inclusion" do
      attrs = Map.put(@valid_attrs, :container_status, "invalid")
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)
      refute changeset.valid?
      assert %{container_status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses" do
      for status <- SessionSchema.valid_statuses() do
        attrs = Map.put(@valid_attrs, :status, status)
        changeset = SessionSchema.changeset(%SessionSchema{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "accepts all valid container statuses" do
      for status <- SessionSchema.valid_container_statuses() do
        attrs = Map.put(@valid_attrs, :container_status, status)
        changeset = SessionSchema.changeset(%SessionSchema{}, attrs)
        assert changeset.valid?, "Expected container_status #{status} to be valid"
      end
    end

    test "accepts optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          title: "My Session",
          container_id: "abc123",
          container_port: 4096,
          container_status: "running",
          image: "custom-image",
          sdk_session_id: "sdk-123",
          paused_at: DateTime.utc_now(),
          resumed_at: DateTime.utc_now(),
          last_activity_at: DateTime.utc_now()
        })

      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)
      assert changeset.valid?
    end

    test "accepts last_activity_at" do
      timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        SessionSchema.changeset(
          %SessionSchema{},
          Map.put(@valid_attrs, :last_activity_at, timestamp)
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :last_activity_at) == timestamp
    end
  end

  describe "status_changeset/2" do
    test "updates mutable fields" do
      session = %SessionSchema{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        status: "active"
      }

      changeset =
        SessionSchema.status_changeset(session, %{
          status: "paused",
          container_status: "stopped",
          paused_at: DateTime.utc_now()
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :status) == "paused"
      assert Ecto.Changeset.get_change(changeset, :container_status) == "stopped"
    end

    test "validates status on update" do
      session = %SessionSchema{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        status: "active"
      }

      changeset = SessionSchema.status_changeset(session, %{status: "invalid"})
      refute changeset.valid?
    end
  end
end

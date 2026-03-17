defmodule Agents.Sessions.Infrastructure.Repositories.SessionRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Domain.Entities.SessionRecord
  alias Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @user_id Ecto.UUID.generate()

  defp create_session_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        user_id: @user_id,
        title: "Test session",
        status: "active",
        container_status: "pending",
        image: "perme8-opencode"
      },
      overrides
    )
  end

  describe "create_session/1" do
    test "returns a SessionRecord with all fields populated" do
      attrs =
        create_session_attrs(%{title: "Create test", container_id: "ctr-1", container_port: 9090})

      assert {:ok, %SessionRecord{} = record} = SessionRepository.create_session(attrs)
      assert is_binary(record.id)
      assert record.user_id == @user_id
      assert record.title == "Create test"
      assert record.status == "active"
      assert record.container_id == "ctr-1"
      assert record.container_port == 9090
      assert record.container_status == "pending"
      assert record.image == "perme8-opencode"
      assert %DateTime{} = record.inserted_at
      assert %DateTime{} = record.updated_at
    end
  end

  describe "get_session/1" do
    test "returns a SessionRecord for an existing session" do
      {:ok, created} = SessionRepository.create_session(create_session_attrs())

      result = SessionRepository.get_session(created.id)

      assert %SessionRecord{} = result
      assert result.id == created.id
      assert result.user_id == @user_id
    end

    test "returns nil for a non-existent session" do
      assert is_nil(SessionRepository.get_session(Ecto.UUID.generate()))
    end
  end

  describe "update_session/2" do
    test "returns an updated SessionRecord" do
      {:ok, created} = SessionRepository.create_session(create_session_attrs())

      assert {:ok, %SessionRecord{} = updated} =
               SessionRepository.update_session(created, %{status: "paused"})

      assert updated.id == created.id
      assert updated.status == "paused"
    end

    test "returns {:error, :not_found} for a non-existent session" do
      fake_record = %SessionRecord{id: Ecto.UUID.generate()}

      assert {:error, :not_found} =
               SessionRepository.update_session(fake_record, %{status: "completed"})
    end
  end

  describe "delete_session/1" do
    test "returns the deleted SessionRecord" do
      {:ok, created} = SessionRepository.create_session(create_session_attrs())

      assert {:ok, %SessionRecord{} = deleted} = SessionRepository.delete_session(created)
      assert deleted.id == created.id

      assert is_nil(SessionRepository.get_session(created.id))
    end

    test "returns {:error, :not_found} for a non-existent session" do
      fake_record = %SessionRecord{id: Ecto.UUID.generate()}

      assert {:error, :not_found} = SessionRepository.delete_session(fake_record)
    end
  end

  describe "get_session_by_container_id/1" do
    test "returns a SessionRecord for an existing container_id" do
      {:ok, created} =
        SessionRepository.create_session(create_session_attrs(%{container_id: "ctr-lookup"}))

      result = SessionRepository.get_session_by_container_id("ctr-lookup")

      assert %SessionRecord{} = result
      assert result.id == created.id
      assert result.container_id == "ctr-lookup"
    end

    test "returns nil for a non-existent container_id" do
      assert is_nil(SessionRepository.get_session_by_container_id("nonexistent"))
    end
  end
end

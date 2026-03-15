defmodule Chat.Infrastructure.Workers.OrphanDetectionWorkerTest do
  use Chat.DataCase, async: true

  import Mox

  alias Chat.Infrastructure.Workers.OrphanDetectionWorker
  alias Chat.Infrastructure.Schemas.SessionSchema
  alias Chat.Mocks.IdentityApiMock

  setup :verify_on_exit!

  describe "init/1" do
    test "starts and schedules first detection" do
      # Stub the mock so Mox.verify! won't complain
      stub(IdentityApiMock, :user_exists?, fn _id -> true end)

      name = :"orphan_worker_#{System.unique_integer([:positive])}"

      {:ok, pid} =
        OrphanDetectionWorker.start_link(
          name: name,
          poll_interval_ms: 60_000,
          identity_api: IdentityApiMock,
          repo: Repo
        )

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "handle_info(:detect_orphans, state)" do
    test "detects sessions with non-existent user_ids and deletes them" do
      existing_user_id = Ecto.UUID.generate()
      orphaned_user_id = Ecto.UUID.generate()

      # Create sessions for both users
      insert_session(%{user_id: existing_user_id})
      insert_session(%{user_id: orphaned_user_id})
      insert_session(%{user_id: orphaned_user_id})

      # Stub: existing user returns true, orphaned returns false
      stub(IdentityApiMock, :user_exists?, fn user_id ->
        user_id == existing_user_id
      end)

      state = %{
        identity_api: IdentityApiMock,
        repo: Repo,
        poll_interval_ms: 60_000,
        sample_size: 100
      }

      # Directly call the handler
      assert {:noreply, ^state} = OrphanDetectionWorker.handle_info(:detect_orphans, state)

      # Orphaned sessions should be deleted
      remaining = Repo.all(from(s in SessionSchema))
      assert length(remaining) == 1
      assert hd(remaining).user_id == existing_user_id
    end

    test "handles empty sample gracefully" do
      # No sessions in the database — no mock calls expected
      state = %{
        identity_api: IdentityApiMock,
        repo: Repo,
        poll_interval_ms: 60_000,
        sample_size: 100
      }

      assert {:noreply, ^state} = OrphanDetectionWorker.handle_info(:detect_orphans, state)
    end

    test "handles Identity API errors gracefully (conservative: keeps sessions)" do
      user_id = Ecto.UUID.generate()
      insert_session(%{user_id: user_id})

      # Stub: Identity raises an exception
      stub(IdentityApiMock, :user_exists?, fn _id -> raise "connection refused" end)

      state = %{
        identity_api: IdentityApiMock,
        repo: Repo,
        poll_interval_ms: 60_000,
        sample_size: 100
      }

      # Should not crash; session stays (errors treated conservatively as "user exists")
      assert {:noreply, ^state} = OrphanDetectionWorker.handle_info(:detect_orphans, state)

      remaining = Repo.all(from(s in SessionSchema))
      assert length(remaining) == 1
    end
  end

  defp insert_session(attrs) do
    base = %{user_id: Ecto.UUID.generate(), title: "Session"}

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end

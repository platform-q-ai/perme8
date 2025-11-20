defmodule Jarga.Agents.QueriesTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents.Queries
  alias Jarga.Repo

  describe "session queries" do
    test "session_base/0 returns base query" do
      query = Queries.session_base()
      assert %Ecto.Query{} = query
    end

    test "for_user/2 filters by user_id" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      sessions = Queries.for_user(user.id) |> Repo.all()

      assert length(sessions) == 1
      assert hd(sessions).id == session.id
    end

    test "by_id_and_user/3 filters by session_id and user_id" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      result = Queries.by_id_and_user(session.id, user.id) |> Repo.one()

      assert result.id == session.id
    end

    test "by_id/2 filters by session_id" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      result = Queries.by_id(session.id) |> Repo.one()

      assert result.id == session.id
    end
  end

  describe "message queries" do
    test "messages_ordered/0 returns base query" do
      query = Queries.messages_ordered()
      assert %Ecto.Query{} = query
    end
  end
end

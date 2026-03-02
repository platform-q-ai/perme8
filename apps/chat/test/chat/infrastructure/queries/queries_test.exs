defmodule Chat.Infrastructure.Queries.QueriesTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Queries.Queries
  alias Chat.Infrastructure.Schemas.{MessageSchema, SessionSchema}

  describe "session queries" do
    test "by_id/1 filters by session ID" do
      session = insert_session()

      results =
        Queries.session_base()
        |> Queries.by_id(session.id)
        |> Repo.all()

      assert [found] = results
      assert found.id == session.id
    end

    test "for_user/1 and by_id_and_user/2 filter by user ownership" do
      user_id = Ecto.UUID.generate()
      other_user_id = Ecto.UUID.generate()
      session = insert_session(%{user_id: user_id})
      _other = insert_session(%{user_id: other_user_id})

      user_results = Queries.session_base() |> Queries.for_user(user_id) |> Repo.all()
      assert Enum.map(user_results, & &1.id) == [session.id]

      assert Queries.session_base() |> Queries.by_id_and_user(session.id, user_id) |> Repo.one()

      assert nil ==
               Queries.session_base()
               |> Queries.by_id_and_user(session.id, other_user_id)
               |> Repo.one()
    end

    test "with_preloads/0 preloads messages only" do
      session = insert_session()
      _m1 = insert_message(%{chat_session_id: session.id, content: "B"})
      _m2 = insert_message(%{chat_session_id: session.id, content: "A"})

      [result] =
        Queries.session_base()
        |> Queries.by_id(session.id)
        |> Queries.with_preloads()
        |> Repo.all()

      assert Ecto.assoc_loaded?(result.messages)
      assert Enum.map(result.messages, & &1.content) == ["B", "A"]
      refute Map.has_key?(result, :user)
      refute Map.has_key?(result, :workspace)
      refute Map.has_key?(result, :project)
    end

    test "with_paginated_messages/2 limits preloaded messages" do
      session = insert_session()
      for i <- 1..5, do: insert_message(%{chat_session_id: session.id, content: "msg #{i}"})

      [result] =
        Queries.session_base()
        |> Queries.by_id(session.id)
        |> Queries.with_paginated_messages(3)
        |> Repo.all()

      assert Ecto.assoc_loaded?(result.messages)
      assert length(result.messages) == 3
    end

    test "ordered_by_recent/0 and with_message_count/0 compose correctly" do
      user_id = Ecto.UUID.generate()
      older = insert_session(%{user_id: user_id})
      newer = insert_session(%{user_id: user_id})
      _ = insert_message(%{chat_session_id: older.id})
      _ = insert_message(%{chat_session_id: newer.id})
      _ = insert_message(%{chat_session_id: newer.id})

      results =
        Queries.session_base()
        |> Queries.for_user(user_id)
        |> Queries.ordered_by_recent()
        |> Queries.with_message_count()
        |> Repo.all()

      by_id = Map.new(results, &{&1.id, &1})
      assert by_id[older.id].message_count == 1
      assert by_id[newer.id].message_count == 2
    end

    test "with_message_count_and_preview/1 returns preview in batch" do
      user_id = Ecto.UUID.generate()
      s1 = insert_session(%{user_id: user_id})
      s2 = insert_session(%{user_id: user_id})
      _ = insert_message(%{chat_session_id: s1.id, content: "Hello from s1"})
      _ = insert_message(%{chat_session_id: s1.id, content: "Second msg"})
      _ = insert_message(%{chat_session_id: s2.id, content: "Hello from s2"})

      results =
        Queries.session_base()
        |> Queries.for_user(user_id)
        |> Queries.with_message_count_and_preview()
        |> Repo.all()

      by_id = Map.new(results, &{&1.id, &1})
      assert by_id[s1.id].preview == "Hello from s1"
      assert by_id[s1.id].message_count == 2
      assert by_id[s2.id].preview == "Hello from s2"
      assert by_id[s2.id].message_count == 1
    end
  end

  describe "message queries" do
    test "first_message_content/1 returns earliest message" do
      session = insert_session()
      _ = insert_message(%{chat_session_id: session.id, content: "First"})
      _ = insert_message(%{chat_session_id: session.id, content: "Second"})

      content = session.id |> Queries.first_message_content() |> Repo.one()
      assert content == "First"
    end

    test "messages_before/3 returns messages older than cursor" do
      session = insert_session()
      m1 = insert_message(%{chat_session_id: session.id, content: "First"})
      _m2 = insert_message(%{chat_session_id: session.id, content: "Second"})
      m3 = insert_message(%{chat_session_id: session.id, content: "Third"})

      results = Queries.messages_before(session.id, m3.id, 10) |> Repo.all()

      result_ids = Enum.map(results, & &1.id)
      refute m3.id in result_ids
      assert m1.id in result_ids
    end

    test "message_by_id_and_user/2 enforces session ownership" do
      user_id = Ecto.UUID.generate()
      session = insert_session(%{user_id: user_id})
      message = insert_message(%{chat_session_id: session.id})

      assert Queries.message_by_id_and_user(message.id, user_id) |> Repo.one()
      assert nil == Queries.message_by_id_and_user(message.id, Ecto.UUID.generate()) |> Repo.one()
    end
  end

  defp insert_session(attrs \\ %{}) do
    base = %{user_id: Ecto.UUID.generate(), title: "Session"}

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp insert_message(attrs) do
    session_id = Map.get(attrs, :chat_session_id) || insert_session().id
    base = %{chat_session_id: session_id, role: "user", content: "hello", context_chunks: []}

    %MessageSchema{}
    |> MessageSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end

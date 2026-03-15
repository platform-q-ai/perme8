defmodule Chat.Application.UseCases.CreateSessionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.CreateSession
  alias Chat.Domain.Events.ChatSessionStarted
  alias Chat.Mocks.{IdentityApiMock, SessionRepositoryMock}
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    bus_name = :"chat_create_session_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: bus_name)
    %{bus_name: bus_name}
  end

  test "creates session with valid attrs and emits event", %{bus_name: bus_name} do
    user_id = Ecto.UUID.generate()
    session_id = Ecto.UUID.generate()

    returned = %{id: session_id, user_id: user_id, workspace_id: nil, title: nil}

    IdentityApiMock
    |> expect(:user_exists?, fn ^user_id -> true end)

    SessionRepositoryMock
    |> expect(:create_session, fn attrs ->
      assert attrs.user_id == user_id
      {:ok, returned}
    end)

    assert {:ok, ^returned} =
             CreateSession.execute(%{user_id: user_id},
               session_repository: SessionRepositoryMock,
               identity_api: IdentityApiMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [%ChatSessionStarted{} = event] = TestEventBus.get_events(name: bus_name)
    assert event.session_id == session_id
    assert event.user_id == user_id
  end

  test "generates title from first message and truncates long values" do
    user_id = Ecto.UUID.generate()
    session_id = Ecto.UUID.generate()
    long = String.duplicate("x", 90)

    IdentityApiMock
    |> expect(:user_exists?, fn ^user_id -> true end)

    SessionRepositoryMock
    |> expect(:create_session, fn attrs ->
      assert String.length(attrs.title) <= 50
      assert String.ends_with?(attrs.title, "...")
      {:ok, %{id: session_id, user_id: user_id, workspace_id: nil, title: attrs.title}}
    end)

    assert {:ok, _session} =
             CreateSession.execute(%{user_id: user_id, first_message: long},
               session_repository: SessionRepositoryMock,
               identity_api: IdentityApiMock
             )
  end

  test "returns error on invalid attrs and does not emit event", %{bus_name: bus_name} do
    user_id = Ecto.UUID.generate()
    changeset = %Ecto.Changeset{valid?: false, errors: [user_id: {"can't be blank", []}]}

    IdentityApiMock
    |> expect(:user_exists?, fn ^user_id -> true end)

    SessionRepositoryMock
    |> expect(:create_session, fn _attrs ->
      {:error, changeset}
    end)

    assert {:error, ^changeset} =
             CreateSession.execute(%{user_id: user_id},
               session_repository: SessionRepositoryMock,
               identity_api: IdentityApiMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [] = TestEventBus.get_events(name: bus_name)
  end

  describe "referential integrity validation" do
    test "returns {:error, :user_not_found} when user does not exist", %{bus_name: bus_name} do
      user_id = Ecto.UUID.generate()

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> false end)

      assert {:error, :user_not_found} =
               CreateSession.execute(%{user_id: user_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )

      assert [] = TestEventBus.get_events(name: bus_name)
    end

    test "returns {:error, :not_a_member} when user is not member of workspace", %{
      bus_name: bus_name
    } do
      user_id = Ecto.UUID.generate()
      workspace_id = Ecto.UUID.generate()

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> true end)
      |> expect(:validate_workspace_access, fn ^user_id, ^workspace_id ->
        {:error, :not_a_member}
      end)

      assert {:error, :not_a_member} =
               CreateSession.execute(%{user_id: user_id, workspace_id: workspace_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )

      assert [] = TestEventBus.get_events(name: bus_name)
    end

    test "succeeds when user exists and workspace_id is nil", %{bus_name: bus_name} do
      user_id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()
      returned = %{id: session_id, user_id: user_id, workspace_id: nil, title: nil}

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> true end)

      SessionRepositoryMock
      |> expect(:create_session, fn _attrs -> {:ok, returned} end)

      assert {:ok, ^returned} =
               CreateSession.execute(%{user_id: user_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )
    end

    test "succeeds when user exists and is member of workspace", %{bus_name: bus_name} do
      user_id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()
      workspace_id = Ecto.UUID.generate()
      returned = %{id: session_id, user_id: user_id, workspace_id: workspace_id, title: nil}

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> true end)
      |> expect(:validate_workspace_access, fn ^user_id, ^workspace_id -> :ok end)

      SessionRepositoryMock
      |> expect(:create_session, fn _attrs -> {:ok, returned} end)

      assert {:ok, ^returned} =
               CreateSession.execute(%{user_id: user_id, workspace_id: workspace_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )
    end

    test "returns {:error, :identity_unavailable} when Identity API raises", %{
      bus_name: bus_name
    } do
      user_id = Ecto.UUID.generate()

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> raise "connection refused" end)

      assert {:error, :identity_unavailable} =
               CreateSession.execute(%{user_id: user_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )

      assert [] = TestEventBus.get_events(name: bus_name)
    end

    test "does not call session_repository when validation fails" do
      user_id = Ecto.UUID.generate()

      IdentityApiMock
      |> expect(:user_exists?, fn ^user_id -> false end)

      # SessionRepositoryMock is NOT expected — no create_session call should happen

      assert {:error, :user_not_found} =
               CreateSession.execute(%{user_id: user_id},
                 session_repository: SessionRepositoryMock,
                 identity_api: IdentityApiMock
               )
    end
  end
end

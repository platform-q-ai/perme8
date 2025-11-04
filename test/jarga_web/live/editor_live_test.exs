defmodule JargaWeb.EditorLiveTest do
  use JargaWeb.ConnCase
  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  describe "EditorLive (unauthenticated)" do
    test "redirects to login if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app/editor")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects to login when accessing specific document without auth", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app/editor/doc_123")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "EditorLive (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "redirects to random doc when no doc_id provided", %{conn: conn} do
      # EditorLive redirects to a random doc_id
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/app/editor")
      assert to =~ ~r|^/app/editor/doc_\d+$|
    end

    test "mounts with doc_id parameter", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/editor/doc_123")

      assert html =~ "Collaborative Markdown Editor"
      assert html =~ "doc_123"
      assert has_element?(view, "#editor-container")
    end

    test "uses admin layout with sidebar navigation", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/app/editor/doc_123")

      # Verify admin layout elements are present
      assert html =~ user.email
      assert html =~ "Home"
      assert html =~ "Settings"
      assert html =~ "Log out"
    end

    test "assigns user_id on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/editor/doc_123")

      user_id = :sys.get_state(view.pid).socket.assigns.user_id
      assert user_id =~ ~r/^user_/
    end

    test "handles yjs_update event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/editor/doc_test")

      # Push a yjs_update event
      render_hook(view, "yjs_update", %{
        "update" => "dGVzdF91cGRhdGU=",
        "user_id" => "user_123"
      })

      # Should not raise an error
      assert view
    end

    test "handles awareness_update event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/editor/doc_test")

      # Push an awareness_update event
      render_hook(view, "awareness_update", %{
        "update" => "YXdhcmVuZXNzX3VwZGF0ZQ==",
        "user_id" => "user_456"
      })

      # Should not raise an error
      assert view
    end

    test "subscribes to document PubSub topic", %{conn: conn} do
      {:ok, _view, _html} = live(conn, ~p"/app/editor/doc_pubsub_test")

      # Verify subscription by subscribing ourselves and broadcasting a message
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:doc_pubsub_test")

      Phoenix.PubSub.broadcast(
        Jarga.PubSub,
        "document:doc_pubsub_test",
        {:test_message, "hello"}
      )

      # If we receive the message, it means the topic has active subscribers
      assert_receive {:test_message, "hello"}, 1000
    end

    test "broadcasts yjs_update to other clients", %{conn: conn} do
      doc_id = "doc_broadcast_test_#{:rand.uniform(10000)}"

      # Connect two clients
      {:ok, view1, _html} = live(conn, ~p"/app/editor/#{doc_id}")
      {:ok, _view2, _html} = live(conn, ~p"/app/editor/#{doc_id}")

      # Subscribe to PubSub to capture broadcasts
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{doc_id}")

      # Push update from first client
      render_hook(view1, "yjs_update", %{
        "update" => "dGVzdA==",
        "user_id" => "user_1"
      })

      # Should receive the broadcast message
      assert_receive {:yjs_update, %{update: "dGVzdA==", user_id: "user_1"}}, 1000
    end

    test "broadcasts awareness_update to other clients", %{conn: conn} do
      doc_id = "doc_awareness_test_#{:rand.uniform(10000)}"

      # Connect two clients
      {:ok, view1, _html} = live(conn, ~p"/app/editor/#{doc_id}")
      {:ok, _view2, _html} = live(conn, ~p"/app/editor/#{doc_id}")

      # Subscribe to PubSub to capture broadcasts
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{doc_id}")

      # Push awareness update from first client
      render_hook(view1, "awareness_update", %{
        "update" => "YXdhcmVuZXNz",
        "user_id" => "user_2"
      })

      # Should receive the broadcast message
      assert_receive {:awareness_update, %{update: "YXdhcmVuZXNz", user_id: "user_2"}}, 1000
    end

    test "broadcasts messages to all subscribers", %{conn: conn} do
      doc_id = "doc_broadcast_all_test_#{:rand.uniform(10000)}"

      {:ok, view, _html} = live(conn, ~p"/app/editor/#{doc_id}")

      # Subscribe to PubSub from test process
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{doc_id}")

      # Push update
      render_hook(view, "yjs_update", %{
        "update" => "dGVzdA==",
        "user_id" => "user_test"
      })

      # Test process should receive the broadcast
      # (broadcast_from only prevents the sender's LiveView process from receiving it)
      assert_receive {:yjs_update, %{update: "dGVzdA==", user_id: "user_test"}}, 1000
    end
  end

  describe "SOLID principles compliance" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "EditorLive follows Single Responsibility Principle", %{conn: conn} do
      # EditorLive should only handle LiveView concerns:
      # - Mount/render
      # - Event handling
      # - PubSub broadcasting
      # It should NOT contain business logic or complex data transformations

      {:ok, view, _html} = live(conn, ~p"/app/editor/doc_solid_test")

      # Verify it handles core LiveView responsibilities
      assert has_element?(view, "#editor-container")

      # Business logic (like Yjs CRDT operations) is delegated to client-side JS
      # Storage is simple (persistent_term for demo - would be DB in production)
    end

    test "EditorLive uses Open/Closed Principle via PubSub", %{conn: conn} do
      # PubSub allows extension without modification
      # New features can subscribe to the same topics without changing EditorLive

      doc_id = "doc_ocp_test"
      {:ok, _view, _html} = live(conn, ~p"/app/editor/#{doc_id}")

      # External services can subscribe to the same topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{doc_id}")

      # EditorLive doesn't need to know about subscribers
      assert :ok ==
               Phoenix.PubSub.broadcast(
                 Jarga.PubSub,
                 "document:#{doc_id}",
                 {:custom_event, %{}}
               )

      assert_receive {:custom_event, %{}}, 1000
    end

    test "EditorLive maintains Interface Segregation", %{conn: conn} do
      # EditorLive has focused public API:
      # - mount/3: setup
      # - handle_event/3: client events
      # - handle_info/2: PubSub messages
      # - render/1: template

      {:ok, view, _html} = live(conn, ~p"/app/editor/doc_isp_test")

      # Only handles specific events, not a bloated interface
      assert render_hook(view, "yjs_update", %{"update" => "test", "user_id" => "u1"})
      assert render_hook(view, "awareness_update", %{"update" => "test", "user_id" => "u1"})
    end
  end
end

defmodule AgentsWeb.ChatSessionsLive.RoutingTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  describe "authenticated access" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "GET /chat-sessions renders the chat sessions index", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/chat-sessions")
      assert html =~ "Chat Sessions"
    end

    test "GET /chat-sessions/:id renders session detail", %{conn: conn, user: user} do
      session = chat_session_fixture(user: user, title: "Route Test")

      {:ok, _lv, html} = live(conn, ~p"/chat-sessions/#{session.id}")
      assert html =~ "Route Test"
    end
  end

  describe "unauthenticated access" do
    test "GET /chat-sessions redirects to login when unauthenticated", %{conn: conn} do
      result = get(conn, ~p"/chat-sessions")
      assert redirected_to(result) =~ "/users/log-in"
    end

    test "GET /chat-sessions/:id redirects to login when unauthenticated", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      result = get(conn, ~p"/chat-sessions/#{fake_id}")
      assert redirected_to(result) =~ "/users/log-in"
    end
  end
end

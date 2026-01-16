defmodule JargaWeb.PageControllerTest do
  use JargaWeb.ConnCase

  describe "GET /" do
    test "renders home page for unauthenticated users", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Ship Features or Kill Tech Debt?"
    end

    test "redirects authenticated users to /app", %{conn: conn} do
      user = Jarga.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/")

      assert redirected_to(conn) == ~p"/app"
    end
  end
end

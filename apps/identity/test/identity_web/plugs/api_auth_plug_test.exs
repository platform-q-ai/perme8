defmodule IdentityWeb.Plugs.ApiAuthPlugTest do
  use IdentityWeb.ConnCase, async: true

  alias IdentityWeb.Plugs.ApiAuthPlug
  alias Plug.Conn

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)

    # Create an active API key
    {:ok, {api_key, plain_token}} =
      Identity.create_api_key(user.id, %{
        name: "Test API Key",
        workspace_access: [workspace.slug]
      })

    %{user: user, api_key: api_key, plain_token: plain_token, workspace: workspace}
  end

  describe "init/1" do
    test "returns options unchanged" do
      assert ApiAuthPlug.init([]) == []
      assert ApiAuthPlug.init(foo: :bar) == [foo: :bar]
    end
  end

  describe "call/2" do
    test "extracts Bearer token from Authorization header and assigns api_key and current_user on success",
         %{
           user: user,
           plain_token: plain_token,
           api_key: api_key
         } do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> ApiAuthPlug.call([])

      refute conn.halted
      assert conn.assigns[:api_key] != nil
      assert conn.assigns[:api_key].id == api_key.id
      assert conn.assigns[:current_user] != nil
      assert conn.assigns[:current_user].id == user.id
    end

    test "returns 401 with JSON error when Authorization header is missing" do
      conn =
        build_conn()
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid or revoked API key"}
    end

    test "returns 401 with JSON error when Authorization header has wrong format" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic sometoken")
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid or revoked API key"}
    end

    test "returns 401 with JSON error when Bearer token is empty" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer ")
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid or revoked API key"}
    end

    test "returns 401 with JSON error when token is invalid" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid-token-12345")
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid or revoked API key"}
    end

    test "returns 401 with JSON error when API key is revoked (inactive)", %{
      user: user,
      api_key: api_key,
      plain_token: plain_token
    } do
      # Revoke the API key
      {:ok, _revoked_key} = Identity.revoke_api_key(user.id, api_key.id)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid or revoked API key"}
    end

    test "sets content-type to application/json on error" do
      conn =
        build_conn()
        |> ApiAuthPlug.call([])

      assert conn.halted
      assert Conn.get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end
end

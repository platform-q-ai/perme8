defmodule EntityRelationshipManager.Plugs.WorkspaceAuthPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias EntityRelationshipManager.Plugs.WorkspaceAuthPlug

  @workspace_id "550e8400-e29b-41d4-a716-446655440000"
  @user_id "660e8400-e29b-41d4-a716-446655440001"
  @api_key_id "770e8400-e29b-41d4-a716-446655440002"
  @token "test-bearer-token"

  defp build_conn(workspace_id \\ @workspace_id) do
    Plug.Test.conn(:get, "/api/v1/workspaces/#{workspace_id}/entities")
    |> Map.put(:params, %{"workspace_id" => workspace_id})
    |> put_req_header("authorization", "Bearer #{@token}")
  end

  defp api_key do
    %{id: @api_key_id, user_id: @user_id}
  end

  defp user do
    %{id: @user_id, email: "test@example.com"}
  end

  defp member do
    %{role: :member, user_id: @user_id, workspace_id: @workspace_id}
  end

  defp deps_all_valid do
    [
      verify_api_key: fn @token -> {:ok, api_key()} end,
      get_user: fn @user_id -> user() end,
      get_member: fn _user, _workspace_id -> {:ok, member()} end
    ]
  end

  describe "call/2" do
    test "assigns current_user, api_key, workspace_id, and member on success" do
      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps_all_valid())

      refute conn.halted
      assert conn.assigns.current_user == user()
      assert conn.assigns.api_key == api_key()
      assert conn.assigns.workspace_id == @workspace_id
      assert conn.assigns.member == member()
    end

    test "returns 401 when Authorization header is missing" do
      conn =
        Plug.Test.conn(:get, "/api/v1/workspaces/#{@workspace_id}/entities")
        |> Map.put(:params, %{"workspace_id" => @workspace_id})
        |> WorkspaceAuthPlug.call(deps_all_valid())

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "unauthorized"
    end

    test "returns 401 when API key is invalid" do
      deps =
        Keyword.merge(deps_all_valid(),
          verify_api_key: fn _token -> {:error, :invalid_api_key} end
        )

      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps)

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when API key is revoked" do
      deps =
        Keyword.merge(deps_all_valid(),
          verify_api_key: fn _token -> {:error, :revoked} end
        )

      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps)

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when user is not found" do
      deps =
        Keyword.merge(deps_all_valid(),
          get_user: fn _id -> nil end
        )

      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps)

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 404 when user is not workspace member (avoids leaking workspace existence)" do
      deps =
        Keyword.merge(deps_all_valid(),
          get_member: fn _user, _ws_id -> {:error, :unauthorized} end
        )

      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps)

      assert conn.halted
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "not_found"
    end

    test "returns 404 when workspace is not found" do
      deps =
        Keyword.merge(deps_all_valid(),
          get_member: fn _user, _ws_id -> {:error, :workspace_not_found} end
        )

      conn =
        build_conn()
        |> WorkspaceAuthPlug.call(deps)

      assert conn.halted
      assert conn.status == 404
    end

    test "returns 400 when workspace_id is invalid UUID" do
      conn =
        build_conn("not-a-uuid")
        |> WorkspaceAuthPlug.call(deps_all_valid())

      assert conn.halted
      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "bad_request"
    end
  end

  describe "init/1" do
    test "passes opts through" do
      assert WorkspaceAuthPlug.init([]) == []
    end
  end
end

defmodule Agents.Infrastructure.Mcp.AuthPlugTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Conn

  alias Agents.Infrastructure.Mcp.AuthPlug
  alias Agents.Test.KnowledgeFixtures, as: Fixtures

  setup :verify_on_exit!

  defp build_conn(headers \\ []) do
    conn =
      Plug.Test.conn(:post, "/mcp")
      |> put_private(:plug_skip_csrf_protection, true)
      |> Map.put(:state, :unset)

    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_req_header(acc, key, value)
    end)
  end

  defp call_plug(conn, opts \\ []) do
    AuthPlug.call(conn, AuthPlug.init(opts))
  end

  describe "extracting Bearer token" do
    test "extracts Bearer token from Authorization header and authenticates" do
      workspace_id = Fixtures.workspace_id()
      user_id = Fixtures.unique_id()

      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "valid-token-123" ->
        {:ok, Fixtures.api_key_struct(%{workspace_access: [workspace_id], user_id: user_id})}
      end)

      conn =
        build_conn([{"authorization", "Bearer valid-token-123"}])
        |> call_plug(identity_module: Agents.Mocks.IdentityMock)

      refute conn.halted
      assert conn.assigns[:workspace_id] == workspace_id
      assert conn.assigns[:user_id] == user_id
    end

    test "handles Bearer prefix case-insensitively" do
      workspace_id = Fixtures.workspace_id()
      user_id = Fixtures.unique_id()

      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "my-token" ->
        {:ok, Fixtures.api_key_struct(%{workspace_access: [workspace_id], user_id: user_id})}
      end)

      conn =
        build_conn([{"authorization", "bearer my-token"}])
        |> call_plug(identity_module: Agents.Mocks.IdentityMock)

      refute conn.halted
      assert conn.assigns[:workspace_id] == workspace_id
    end
  end

  describe "error responses" do
    test "returns 401 when Authorization header is missing" do
      conn =
        build_conn()
        |> call_plug()

      assert conn.halted
      assert conn.status == 401

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "unauthorized",
               "message" => "Missing or invalid Authorization header"
             }
    end

    test "returns 401 when token is invalid" do
      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "bad-token" ->
        {:error, :invalid}
      end)

      conn =
        build_conn([{"authorization", "Bearer bad-token"}])
        |> call_plug(identity_module: Agents.Mocks.IdentityMock)

      assert conn.halted
      assert conn.status == 401

      assert Jason.decode!(conn.resp_body) == %{
               "error" => "unauthorized",
               "message" => "Invalid or expired API key"
             }
    end

    test "returns 401 when token is inactive" do
      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "inactive-token" ->
        {:error, :inactive}
      end)

      conn =
        build_conn([{"authorization", "Bearer inactive-token"}])
        |> call_plug(identity_module: Agents.Mocks.IdentityMock)

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for non-Bearer auth schemes" do
      conn =
        build_conn([{"authorization", "Basic dXNlcjpwYXNz"}])
        |> call_plug()

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when API key has no workspace access" do
      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "no-workspace-token" ->
        {:ok, Fixtures.api_key_struct(%{workspace_access: []})}
      end)

      conn =
        build_conn([{"authorization", "Bearer no-workspace-token"}])
        |> call_plug(identity_module: Agents.Mocks.IdentityMock)

      assert conn.halted
      assert conn.status == 401
    end
  end
end

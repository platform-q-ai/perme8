defmodule Agents.Infrastructure.Mcp.RouterTest do
  @moduledoc """
  Tests for the MCP Router that composes AuthPlug with the Hermes
  StreamableHTTP transport Plug.

  Tests verify:
  - Unauthenticated requests are rejected with 401
  - Authenticated requests are forwarded to the MCP transport
  - The router properly chains auth and transport plugs
  """
  use ExUnit.Case, async: false

  import Mox
  import Plug.Conn
  import Plug.Test

  alias Agents.Infrastructure.Mcp.Router
  alias Agents.Test.KnowledgeFixtures, as: Fixtures

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)

    # Hermes.Server.Registry and MCP Server are started by the Agents.OTPApp
    # supervisor, so we don't need to start them here.

    on_exit(fn -> Application.delete_env(:agents, :identity_module) end)
    :ok
  end

  describe "unauthenticated requests" do
    test "returns 401 when no Authorization header is present" do
      conn =
        :post
        |> conn("/", Jason.encode!(%{jsonrpc: "2.0", method: "initialize", id: 1}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/event-stream")
        |> Router.call(Router.init([]))

      assert conn.status == 401
      assert conn.halted

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "unauthorized"
    end

    test "returns 401 when invalid API key is provided" do
      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "bad-key" -> {:error, :invalid} end)

      conn =
        :post
        |> conn("/", Jason.encode!(%{jsonrpc: "2.0", method: "initialize", id: 1}))
        |> put_req_header("authorization", "Bearer bad-key")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/event-stream")
        |> Router.call(Router.init([]))

      assert conn.status == 401
      assert conn.halted
    end
  end

  describe "authenticated requests" do
    test "forwards authenticated requests to MCP transport" do
      workspace_slug = Fixtures.workspace_id()
      workspace_uuid = Fixtures.unique_id()
      user_id = Fixtures.unique_id()

      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "valid-key" ->
        {:ok, Fixtures.api_key_struct(%{workspace_access: [workspace_slug], user_id: user_id})}
      end)
      |> expect(:resolve_workspace_id, fn ^workspace_slug -> {:ok, workspace_uuid} end)

      conn =
        :post
        |> conn(
          "/",
          Jason.encode!(%{
            jsonrpc: "2.0",
            method: "initialize",
            id: 1,
            params: %{
              protocolVersion: "2024-11-05",
              capabilities: %{},
              clientInfo: %{name: "test", version: "1.0"}
            }
          })
        )
        |> put_req_header("authorization", "Bearer valid-key")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/event-stream")
        |> Router.call(Router.init([]))

      # After auth, request is forwarded to Hermes transport
      # A successful MCP initialize should return 200 with server info
      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert body["result"]["serverInfo"]["name"] == "knowledge-mcp"
      assert body["result"]["serverInfo"]["version"] == "1.0.0"
    end

    test "assigns workspace_id and user_id from authentication" do
      workspace_slug = Fixtures.workspace_id()
      workspace_uuid = Fixtures.unique_id()
      user_id = Fixtures.unique_id()

      Agents.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "valid-key" ->
        {:ok, Fixtures.api_key_struct(%{workspace_access: [workspace_slug], user_id: user_id})}
      end)
      |> expect(:resolve_workspace_id, fn ^workspace_slug -> {:ok, workspace_uuid} end)

      conn =
        :post
        |> conn(
          "/",
          Jason.encode!(%{
            jsonrpc: "2.0",
            method: "initialize",
            id: 2,
            params: %{
              protocolVersion: "2024-11-05",
              capabilities: %{},
              clientInfo: %{name: "test", version: "1.0"}
            }
          })
        )
        |> put_req_header("authorization", "Bearer valid-key")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/event-stream")
        |> Router.call(Router.init([]))

      # Verify assigns were set (they pass through to the Hermes transport context)
      assert conn.assigns[:workspace_id] == workspace_uuid
      assert conn.assigns[:user_id] == user_id
    end
  end
end

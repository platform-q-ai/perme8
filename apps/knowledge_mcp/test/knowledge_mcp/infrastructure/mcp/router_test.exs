defmodule KnowledgeMcp.Infrastructure.Mcp.RouterTest do
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

  alias KnowledgeMcp.Infrastructure.Mcp.Router

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:knowledge_mcp, :identity_module, KnowledgeMcp.Mocks.IdentityMock)
    on_exit(fn -> Application.delete_env(:knowledge_mcp, :identity_module) end)
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
      KnowledgeMcp.Mocks.IdentityMock
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
      workspace_id = "ws-test-router"
      user_id = "user-test-router"

      KnowledgeMcp.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "valid-key" ->
        {:ok,
         %{
           id: "api-key-id",
           user_id: user_id,
           workspace_access: [workspace_id],
           is_active: true
         }}
      end)

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
      workspace_id = "ws-assign-test"
      user_id = "user-assign-test"

      KnowledgeMcp.Mocks.IdentityMock
      |> expect(:verify_api_key, fn "valid-key" ->
        {:ok,
         %{
           id: "api-key-id",
           user_id: user_id,
           workspace_access: [workspace_id],
           is_active: true
         }}
      end)

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
      assert conn.assigns[:workspace_id] == workspace_id
      assert conn.assigns[:user_id] == user_id
    end
  end
end

defmodule Agents.Application.UseCases.AuthenticateMcpRequestTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.AuthenticateMcpRequest
  alias Agents.Mocks.IdentityMock

  import Agents.Test.KnowledgeFixtures

  setup :verify_on_exit!

  describe "execute/2" do
    test "returns {:ok, context} for valid API key with workspace access" do
      user_id = unique_id()
      ws_slug = workspace_id()
      ws_uuid = unique_id()

      api_key = api_key_struct(%{user_id: user_id, workspace_access: [ws_slug], is_active: true})

      IdentityMock
      |> expect(:verify_api_key, fn "valid-token" -> {:ok, api_key} end)
      |> expect(:resolve_workspace_id, fn ^ws_slug -> {:ok, ws_uuid} end)

      assert {:ok, %{workspace_id: ^ws_uuid, user_id: ^user_id}} =
               AuthenticateMcpRequest.execute("valid-token", identity_module: IdentityMock)
    end

    test "uses first workspace_id from workspace_access list" do
      ws1 = "ws-first"
      ws1_uuid = unique_id()
      ws2 = "ws-second"

      api_key = api_key_struct(%{workspace_access: [ws1, ws2]})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)
      |> expect(:resolve_workspace_id, fn ^ws1 -> {:ok, ws1_uuid} end)

      assert {:ok, %{workspace_id: ^ws1_uuid}} =
               AuthenticateMcpRequest.execute("token", identity_module: IdentityMock)
    end

    test "returns {:error, :unauthorized} for invalid API key" do
      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:error, :invalid} end)

      assert {:error, :unauthorized} =
               AuthenticateMcpRequest.execute("bad-token", identity_module: IdentityMock)
    end

    test "returns {:error, :unauthorized} for inactive API key" do
      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:error, :inactive} end)

      assert {:error, :unauthorized} =
               AuthenticateMcpRequest.execute("inactive-token", identity_module: IdentityMock)
    end

    test "returns {:error, :no_workspace_access} when workspace_access is empty" do
      api_key = api_key_struct(%{workspace_access: []})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)

      assert {:error, :no_workspace_access} =
               AuthenticateMcpRequest.execute("token", identity_module: IdentityMock)
    end

    test "returns {:error, :workspace_not_found} when workspace slug cannot be resolved" do
      api_key = api_key_struct(%{workspace_access: ["ghost-workspace"]})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)
      |> expect(:resolve_workspace_id, fn "ghost-workspace" -> {:error, :not_found} end)

      assert {:error, :workspace_not_found} =
               AuthenticateMcpRequest.execute("token", identity_module: IdentityMock)
    end
  end
end

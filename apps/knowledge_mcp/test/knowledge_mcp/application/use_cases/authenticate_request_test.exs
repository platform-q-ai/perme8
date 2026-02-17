defmodule KnowledgeMcp.Application.UseCases.AuthenticateRequestTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Application.UseCases.AuthenticateRequest
  alias KnowledgeMcp.Mocks.IdentityMock

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  describe "execute/2" do
    test "returns {:ok, context} for valid API key with workspace access" do
      user_id = unique_id()
      ws_id = workspace_id()

      api_key = api_key_struct(%{user_id: user_id, workspace_access: [ws_id], is_active: true})

      IdentityMock
      |> expect(:verify_api_key, fn "valid-token" -> {:ok, api_key} end)

      assert {:ok, %{workspace_id: ^ws_id, user_id: ^user_id}} =
               AuthenticateRequest.execute("valid-token", identity_module: IdentityMock)
    end

    test "uses first workspace_id from workspace_access list" do
      ws1 = "ws-first"
      ws2 = "ws-second"

      api_key = api_key_struct(%{workspace_access: [ws1, ws2]})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)

      assert {:ok, %{workspace_id: ^ws1}} =
               AuthenticateRequest.execute("token", identity_module: IdentityMock)
    end

    test "returns {:error, :unauthorized} for invalid API key" do
      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:error, :invalid} end)

      assert {:error, :unauthorized} =
               AuthenticateRequest.execute("bad-token", identity_module: IdentityMock)
    end

    test "returns {:error, :unauthorized} for inactive API key" do
      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:error, :inactive} end)

      assert {:error, :unauthorized} =
               AuthenticateRequest.execute("inactive-token", identity_module: IdentityMock)
    end

    test "returns {:error, :no_workspace_access} when workspace_access is empty" do
      api_key = api_key_struct(%{workspace_access: []})

      IdentityMock
      |> expect(:verify_api_key, fn _ -> {:ok, api_key} end)

      assert {:error, :no_workspace_access} =
               AuthenticateRequest.execute("token", identity_module: IdentityMock)
    end
  end
end

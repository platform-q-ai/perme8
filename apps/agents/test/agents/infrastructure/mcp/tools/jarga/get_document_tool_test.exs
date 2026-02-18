defmodule Agents.Infrastructure.Mcp.Tools.Jarga.GetDocumentToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.GetDocumentTool
  alias Agents.Test.JargaFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  defp build_frame(workspace_id, user_id) do
    Frame.new(%{workspace_id: workspace_id, user_id: user_id})
  end

  describe "execute/2" do
    test "returns document details" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      document =
        Fixtures.document_map(%{
          title: "My Document",
          slug: "my-document",
          is_public: false
        })

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn ^user_id, ^workspace_id, "my-document" ->
        {:ok, document}
      end)

      params = %{slug: "my-document"}

      assert {:reply, response, ^frame} = GetDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "My Document"
      assert text =~ "my-document"
    end

    test "handles document not found" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn ^user_id, ^workspace_id, "nonexistent" ->
        {:error, :document_not_found}
      end)

      params = %{slug: "nonexistent"}

      assert {:reply, response, ^frame} = GetDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "not found"
    end

    test "handles forbidden error" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn ^user_id, ^workspace_id, "private-doc" ->
        {:error, :forbidden}
      end)

      params = %{slug: "private-doc"}

      assert {:reply, response, ^frame} = GetDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Access denied"
    end
  end
end

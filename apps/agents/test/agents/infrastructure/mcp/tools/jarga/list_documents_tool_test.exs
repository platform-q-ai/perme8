defmodule Agents.Infrastructure.Mcp.Tools.Jarga.ListDocumentsToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.ListDocumentsTool
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
    test "returns workspace-level documents list" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      doc1 = Fixtures.document_map(%{title: "Doc Alpha", slug: "doc-alpha"})
      doc2 = Fixtures.document_map(%{title: "Doc Beta", slug: "doc-beta"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn ^user_id, ^workspace_id, [] ->
        {:ok, [doc1, doc2]}
      end)

      params = %{}

      assert {:reply, response, ^frame} = ListDocumentsTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Doc Alpha"
      assert text =~ "Doc Beta"
    end

    test "returns project-level documents when project_slug provided" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      project = Fixtures.project_map(%{slug: "my-project"})
      doc = Fixtures.document_map(%{title: "Project Doc", slug: "project-doc"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn ^user_id, ^workspace_id, "my-project" ->
        {:ok, project}
      end)
      |> expect(:list_documents, fn ^user_id, ^workspace_id, [project_id: _] ->
        {:ok, [doc]}
      end)

      params = %{project_slug: "my-project"}

      assert {:reply, response, ^frame} = ListDocumentsTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Project Doc"
    end

    test "returns message when no documents found" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn ^user_id, ^workspace_id, [] ->
        {:ok, []}
      end)

      params = %{}

      assert {:reply, response, ^frame} = ListDocumentsTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "No documents found"
    end
  end
end

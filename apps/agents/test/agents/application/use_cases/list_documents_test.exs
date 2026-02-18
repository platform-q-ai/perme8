defmodule Agents.Application.UseCases.ListDocumentsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.ListDocuments

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/4 workspace-level listing" do
    test "returns all documents in a workspace when no project_slug" do
      doc = %{id: "doc-1", title: "My Doc", slug: "my-doc"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} = ListDocuments.execute("user-1", "ws-1", %{})
    end

    test "returns empty list when workspace has no documents" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:ok, []} end)

      assert {:ok, []} = ListDocuments.execute("user-1", "ws-1", %{})
    end
  end

  describe "execute/4 project-level listing" do
    test "resolves project_slug to project_id and filters documents" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}
      doc = %{id: "doc-1", title: "Project Doc", slug: "project-doc"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "my-project" -> {:ok, project} end)
      |> expect(:list_documents, fn "user-1", "ws-1", [project_id: "proj-1"] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} =
               ListDocuments.execute("user-1", "ws-1", %{project_slug: "my-project"})
    end

    test "returns project_not_found when project_slug doesn't resolve" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "nonexistent" ->
        {:error, :project_not_found}
      end)

      assert {:error, :project_not_found} =
               ListDocuments.execute("user-1", "ws-1", %{project_slug: "nonexistent"})
    end
  end

  describe "execute/4 error propagation" do
    test "propagates list_documents gateway error" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:error, :gateway_error} end)

      assert {:error, :gateway_error} = ListDocuments.execute("user-1", "ws-1", %{})
    end
  end

  describe "execute/4 dependency injection" do
    test "accepts jarga_gateway via opts" do
      doc = %{id: "doc-2", title: "Injected Doc", slug: "injected-doc"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn "user-2", "ws-2", [] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} =
               ListDocuments.execute("user-2", "ws-2", %{},
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end

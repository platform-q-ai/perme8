defmodule Agents.Application.UseCases.ListDocumentsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.ListDocuments

  @gateway Agents.Mocks.JargaGatewayMock
  @opts [jarga_gateway: @gateway]

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "execute/4 workspace-level listing" do
    test "returns all documents in a workspace when no project_slug" do
      doc = %{id: "doc-1", title: "My Doc", slug: "my-doc"}

      @gateway
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} = ListDocuments.execute("user-1", "ws-1", %{}, @opts)
    end

    test "returns empty list when workspace has no documents" do
      @gateway
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:ok, []} end)

      assert {:ok, []} = ListDocuments.execute("user-1", "ws-1", %{}, @opts)
    end
  end

  describe "execute/4 project-level listing" do
    test "resolves project_slug to project_id and filters documents" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}
      doc = %{id: "doc-1", title: "Project Doc", slug: "project-doc"}

      @gateway
      |> expect(:get_project, fn "user-1", "ws-1", "my-project" -> {:ok, project} end)
      |> expect(:list_documents, fn "user-1", "ws-1", [project_id: "proj-1"] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} =
               ListDocuments.execute("user-1", "ws-1", %{project_slug: "my-project"}, @opts)
    end

    test "returns project_not_found when project_slug doesn't resolve" do
      @gateway
      |> expect(:get_project, fn "user-1", "ws-1", "nonexistent" ->
        {:error, :project_not_found}
      end)

      assert {:error, :project_not_found} =
               ListDocuments.execute("user-1", "ws-1", %{project_slug: "nonexistent"}, @opts)
    end
  end

  describe "execute/4 error propagation" do
    test "propagates list_documents gateway error" do
      @gateway
      |> expect(:list_documents, fn "user-1", "ws-1", [] -> {:error, :gateway_error} end)

      assert {:error, :gateway_error} = ListDocuments.execute("user-1", "ws-1", %{}, @opts)
    end
  end

  describe "execute/4 dependency injection" do
    test "accepts jarga_gateway via opts" do
      doc = %{id: "doc-2", title: "Injected Doc", slug: "injected-doc"}

      @gateway
      |> expect(:list_documents, fn "user-2", "ws-2", [] -> {:ok, [doc]} end)

      assert {:ok, [^doc]} =
               ListDocuments.execute("user-2", "ws-2", %{}, @opts)
    end
  end
end

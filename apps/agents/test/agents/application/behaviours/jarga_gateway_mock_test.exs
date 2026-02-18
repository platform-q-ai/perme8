defmodule Agents.Application.Behaviours.JargaGatewayMockTest do
  @moduledoc """
  Verifies the JargaGatewayMock can be used with Mox expectations.
  """
  use ExUnit.Case, async: false

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "JargaGatewayMock" do
    test "can set expectations on list_workspaces/1" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_workspaces, fn "user-1" -> {:ok, [%{name: "My Workspace"}]} end)

      assert {:ok, [%{name: "My Workspace"}]} =
               Agents.Mocks.JargaGatewayMock.list_workspaces("user-1")
    end

    test "can set expectations on get_workspace/2" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_workspace, fn "user-1", "my-workspace" ->
        {:ok, %{slug: "my-workspace"}}
      end)

      assert {:ok, %{slug: "my-workspace"}} =
               Agents.Mocks.JargaGatewayMock.get_workspace("user-1", "my-workspace")
    end

    test "can set expectations on list_projects/2" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_projects, fn "user-1", "ws-id" -> {:ok, []} end)

      assert {:ok, []} = Agents.Mocks.JargaGatewayMock.list_projects("user-1", "ws-id")
    end

    test "can set expectations on create_project/3" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn "user-1", "ws-id", %{name: "New"} ->
        {:ok, %{name: "New"}}
      end)

      assert {:ok, %{name: "New"}} =
               Agents.Mocks.JargaGatewayMock.create_project("user-1", "ws-id", %{name: "New"})
    end

    test "can set expectations on get_project/3" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-id", "proj-slug" ->
        {:ok, %{slug: "proj-slug"}}
      end)

      assert {:ok, %{slug: "proj-slug"}} =
               Agents.Mocks.JargaGatewayMock.get_project("user-1", "ws-id", "proj-slug")
    end

    test "can set expectations on list_documents/3" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:list_documents, fn "user-1", "ws-id", [] -> {:ok, []} end)

      assert {:ok, []} =
               Agents.Mocks.JargaGatewayMock.list_documents("user-1", "ws-id", [])
    end

    test "can set expectations on create_document/3" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-id", %{title: "Doc"} ->
        {:ok, %{title: "Doc"}}
      end)

      assert {:ok, %{title: "Doc"}} =
               Agents.Mocks.JargaGatewayMock.create_document("user-1", "ws-id", %{title: "Doc"})
    end

    test "can set expectations on get_document/3" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn "user-1", "ws-id", "doc-slug" ->
        {:ok, %{slug: "doc-slug"}}
      end)

      assert {:ok, %{slug: "doc-slug"}} =
               Agents.Mocks.JargaGatewayMock.get_document("user-1", "ws-id", "doc-slug")
    end
  end
end

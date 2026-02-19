defmodule Agents.Infrastructure.Mcp.Tools.Jarga.CreateDocumentToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.CreateDocumentTool
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
    test "creates document and returns success" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      created_doc =
        Fixtures.document_map(%{title: "New Doc", slug: "new-doc", is_public: false})

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn ^user_id, ^workspace_id, attrs ->
        assert attrs.title == "New Doc"
        assert attrs.is_public == false
        {:ok, created_doc}
      end)

      params = %{title: "New Doc", content: nil, visibility: nil, project_slug: nil}

      assert {:reply, response, ^frame} = CreateDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Created document"
      assert text =~ "New Doc"
      assert text =~ "new-doc"
    end

    test "creates document with project_slug" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      project = Fixtures.project_map(%{slug: "my-project"})

      created_doc =
        Fixtures.document_map(%{title: "Project Doc", slug: "project-doc"})

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn ^user_id, ^workspace_id, "my-project" ->
        {:ok, project}
      end)
      |> expect(:create_document, fn ^user_id, ^workspace_id, attrs ->
        assert attrs.project_id == project.id
        {:ok, created_doc}
      end)

      params = %{title: "Project Doc", content: nil, visibility: nil, project_slug: "my-project"}

      assert {:reply, response, ^frame} = CreateDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Created document"
      assert text =~ "Project Doc"
    end

    test "creates document with public visibility" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      created_doc =
        Fixtures.document_map(%{title: "Public Doc", slug: "public-doc", is_public: true})

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn ^user_id, ^workspace_id, attrs ->
        assert attrs.is_public == true
        {:ok, created_doc}
      end)

      params = %{title: "Public Doc", content: nil, visibility: "public", project_slug: nil}

      assert {:reply, response, ^frame} = CreateDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
    end

    test "handles validation error from changeset" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      changeset =
        %Ecto.Changeset{
          valid?: false,
          errors: [title: {"can't be blank", [validation: :required]}],
          data: %{},
          types: %{}
        }

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn ^user_id, ^workspace_id, _attrs ->
        {:error, changeset}
      end)

      params = %{title: "", content: nil, visibility: nil, project_slug: nil}

      assert {:reply, response, ^frame} = CreateDocumentTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "title"
    end
  end
end

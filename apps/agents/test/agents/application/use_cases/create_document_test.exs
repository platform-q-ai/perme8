defmodule Agents.Application.UseCases.CreateDocumentTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.CreateDocument

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/4 basic creation" do
    test "creates a document without project or visibility" do
      attrs = %{title: "My Doc", body: "Content here"}
      created = %{id: "doc-1", title: "My Doc", slug: "my-doc", body: "Content here"}

      expected_attrs = Map.put(attrs, :is_public, false)

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs -> {:ok, created} end)

      assert {:ok, ^created} = CreateDocument.execute("user-1", "ws-1", attrs)
    end

    test "returns validation error from gateway" do
      attrs = %{title: ""}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-1", _attrs -> {:error, :validation_error} end)

      assert {:error, :validation_error} = CreateDocument.execute("user-1", "ws-1", attrs)
    end
  end

  describe "execute/4 with project_slug resolution" do
    test "resolves project_slug to project_id in attrs" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}
      attrs = %{title: "Project Doc", body: "Content", project_slug: "my-project"}

      expected_attrs = %{
        title: "Project Doc",
        body: "Content",
        project_id: "proj-1",
        is_public: false
      }

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "my-project" -> {:ok, project} end)
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs ->
        {:ok, %{id: "doc-1"}}
      end)

      assert {:ok, %{id: "doc-1"}} =
               CreateDocument.execute("user-1", "ws-1", attrs)
    end

    test "returns error when project_slug not found" do
      attrs = %{title: "Doc", project_slug: "nonexistent"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "nonexistent" ->
        {:error, :project_not_found}
      end)

      assert {:error, :project_not_found} = CreateDocument.execute("user-1", "ws-1", attrs)
    end
  end

  describe "execute/4 visibility translation" do
    test "translates visibility: public to is_public: true" do
      attrs = %{title: "Public Doc", body: "Content", visibility: "public"}
      expected_attrs = %{title: "Public Doc", body: "Content", is_public: true}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs ->
        {:ok, %{id: "doc-1"}}
      end)

      assert {:ok, %{id: "doc-1"}} = CreateDocument.execute("user-1", "ws-1", attrs)
    end

    test "translates visibility: private to is_public: false" do
      attrs = %{title: "Private Doc", body: "Content", visibility: "private"}
      expected_attrs = %{title: "Private Doc", body: "Content", is_public: false}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs ->
        {:ok, %{id: "doc-1"}}
      end)

      assert {:ok, %{id: "doc-1"}} = CreateDocument.execute("user-1", "ws-1", attrs)
    end

    test "defaults to is_public: false when visibility is nil" do
      attrs = %{title: "Default Doc", body: "Content", visibility: nil}
      expected_attrs = %{title: "Default Doc", body: "Content", is_public: false}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs ->
        {:ok, %{id: "doc-1"}}
      end)

      assert {:ok, %{id: "doc-1"}} = CreateDocument.execute("user-1", "ws-1", attrs)
    end
  end

  describe "execute/4 combined project_slug and visibility" do
    test "resolves both project_slug and visibility in a single call" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}

      attrs = %{
        title: "Full Doc",
        body: "Content",
        project_slug: "my-project",
        visibility: "public"
      }

      expected_attrs = %{
        title: "Full Doc",
        body: "Content",
        project_id: "proj-1",
        is_public: true
      }

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "my-project" -> {:ok, project} end)
      |> expect(:create_document, fn "user-1", "ws-1", ^expected_attrs ->
        {:ok, %{id: "doc-1"}}
      end)

      assert {:ok, %{id: "doc-1"}} = CreateDocument.execute("user-1", "ws-1", attrs)
    end
  end

  describe "execute/4 dependency injection" do
    test "accepts jarga_gateway via opts" do
      attrs = %{title: "Injected", body: "Content"}
      expected_attrs = Map.put(attrs, :is_public, false)

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_document, fn "user-2", "ws-2", ^expected_attrs ->
        {:ok, %{id: "doc-2"}}
      end)

      assert {:ok, %{id: "doc-2"}} =
               CreateDocument.execute("user-2", "ws-2", attrs,
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end

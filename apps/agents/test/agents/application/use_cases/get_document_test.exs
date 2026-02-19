defmodule Agents.Application.UseCases.GetDocumentTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.GetDocument

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/4" do
    test "returns document by slug" do
      document = %{id: "doc-1", title: "My Document", slug: "my-document", body: "Content"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn "user-1", "ws-1", "my-document" -> {:ok, document} end)

      assert {:ok, ^document} = GetDocument.execute("user-1", "ws-1", "my-document")
    end

    test "returns not_found when document does not exist" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn "user-1", "ws-1", "nonexistent" ->
        {:error, :document_not_found}
      end)

      assert {:error, :document_not_found} =
               GetDocument.execute("user-1", "ws-1", "nonexistent")
    end

    test "returns forbidden when user lacks access" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn "user-1", "ws-1", "private-doc" -> {:error, :forbidden} end)

      assert {:error, :forbidden} = GetDocument.execute("user-1", "ws-1", "private-doc")
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      document = %{id: "doc-2", title: "Injected", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_document, fn "user-2", "ws-2", "injected" -> {:ok, document} end)

      assert {:ok, ^document} =
               GetDocument.execute("user-2", "ws-2", "injected",
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end

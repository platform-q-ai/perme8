defmodule Agents.Application.UseCases.GetProjectTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.GetProject

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/4" do
    test "returns project by slug" do
      project = %{id: "proj-1", name: "My Project", slug: "my-project"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "my-project" -> {:ok, project} end)

      assert {:ok, ^project} = GetProject.execute("user-1", "ws-1", "my-project")
    end

    test "returns not_found when project does not exist" do
      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-1", "ws-1", "nonexistent" ->
        {:error, :project_not_found}
      end)

      assert {:error, :project_not_found} = GetProject.execute("user-1", "ws-1", "nonexistent")
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      project = %{id: "proj-2", name: "Injected", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:get_project, fn "user-2", "ws-2", "injected" -> {:ok, project} end)

      assert {:ok, ^project} =
               GetProject.execute("user-2", "ws-2", "injected",
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end

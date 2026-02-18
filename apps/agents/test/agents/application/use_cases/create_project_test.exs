defmodule Agents.Application.UseCases.CreateProjectTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Application.UseCases.CreateProject

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :jarga_gateway, Agents.Mocks.JargaGatewayMock)
    on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)
    :ok
  end

  describe "execute/4" do
    test "creates a project successfully" do
      attrs = %{name: "New Project", description: "A great project"}

      created = %{
        id: "proj-1",
        name: "New Project",
        slug: "new-project",
        description: "A great project"
      }

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn "user-1", "ws-1", ^attrs -> {:ok, created} end)

      assert {:ok, ^created} = CreateProject.execute("user-1", "ws-1", attrs)
    end

    test "returns validation error" do
      attrs = %{name: ""}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn "user-1", "ws-1", ^attrs -> {:error, :validation_error} end)

      assert {:error, :validation_error} = CreateProject.execute("user-1", "ws-1", attrs)
    end

    test "returns unauthorized when user lacks permission" do
      attrs = %{name: "Secret Project"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn "user-1", "ws-1", ^attrs -> {:error, :unauthorized} end)

      assert {:error, :unauthorized} = CreateProject.execute("user-1", "ws-1", attrs)
    end

    test "accepts jarga_gateway via opts for dependency injection" do
      attrs = %{name: "Injected"}
      created = %{id: "proj-2", name: "Injected", slug: "injected"}

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn "user-2", "ws-2", ^attrs -> {:ok, created} end)

      assert {:ok, ^created} =
               CreateProject.execute("user-2", "ws-2", attrs,
                 jarga_gateway: Agents.Mocks.JargaGatewayMock
               )
    end
  end
end

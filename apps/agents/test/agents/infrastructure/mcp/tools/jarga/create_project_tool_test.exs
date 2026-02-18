defmodule Agents.Infrastructure.Mcp.Tools.Jarga.CreateProjectToolTest do
  use ExUnit.Case, async: false

  import Mox

  alias Agents.Infrastructure.Mcp.Tools.Jarga.CreateProjectTool
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
    test "creates project and returns success" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      created_project =
        Fixtures.project_map(%{
          name: "New Project",
          slug: "new-project",
          description: "A description"
        })

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn ^user_id, ^workspace_id, attrs ->
        assert attrs.name == "New Project"
        assert attrs.description == "A description"
        {:ok, created_project}
      end)

      params = %{name: "New Project", description: "A description"}

      assert {:reply, response, ^frame} = CreateProjectTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Created project"
      assert text =~ "New Project"
      assert text =~ "new-project"
    end

    test "handles validation error from changeset" do
      user_id = Fixtures.user_id()
      workspace_id = Fixtures.workspace_id()
      frame = build_frame(workspace_id, user_id)

      changeset =
        %Ecto.Changeset{
          valid?: false,
          errors: [name: {"can't be blank", [validation: :required]}],
          data: %{},
          types: %{}
        }

      Agents.Mocks.JargaGatewayMock
      |> expect(:create_project, fn ^user_id, ^workspace_id, _attrs ->
        {:error, changeset}
      end)

      params = %{name: "", description: nil}

      assert {:reply, response, ^frame} = CreateProjectTool.execute(params, frame)

      assert %Hermes.Server.Response{type: :tool, isError: true} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "name"
    end
  end
end

defmodule EntityRelationshipManager.Application.UseCases.GetSchemaTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.GetSchema
  alias EntityRelationshipManager.Mocks.SchemaRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/2" do
    test "returns schema when found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn ws_id ->
        assert ws_id == workspace_id()
        {:ok, schema}
      end)

      assert {:ok, ^schema} =
               GetSchema.execute(workspace_id(), schema_repo: SchemaRepositoryMock)
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               GetSchema.execute(workspace_id(), schema_repo: SchemaRepositoryMock)
    end
  end
end

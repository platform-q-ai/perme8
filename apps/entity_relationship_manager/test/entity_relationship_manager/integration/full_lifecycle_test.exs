defmodule EntityRelationshipManager.Integration.FullLifecycleTest do
  @moduledoc """
  Integration test exercising the complete Entity Relationship Manager lifecycle.

  Validates the full workflow through the HTTP API:
    1. Define schema with entity types (Person, Company) and edge types (EMPLOYS)
    2. Create entity (Person with valid properties)
    3. Create entity (Company)
    4. Create edge (Company EMPLOYS Person)
    5. Get neighbors of Company -> includes Person
    6. Get paths from Person to Company
    7. Update Person properties
    8. Delete Person (soft) -> verify cascading edge soft-delete
    9. List entities to verify post-deletion state

  Tagged `:integration` so it is excluded by default. Enable with:

      mix test --include integration

  When real PostgreSQL and Neo4j infrastructure is provisioned, these tests
  will run end-to-end. Until then, they use mocks to document expected behavior
  and verify the API contract.
  """

  use EntityRelationshipManager.ConnCase, async: true

  @moduletag :integration

  alias EntityRelationshipManager.UseCaseFixtures
  alias EntityRelationshipManager.Domain.Entities.{Entity, Edge}

  describe "full entity lifecycle" do
    test "schema -> create entities -> create edges -> traverse -> update -> soft-delete",
         %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)

      # ---------------------------------------------------------------
      # Fixture data representing what the repositories would return
      # ---------------------------------------------------------------
      person_id = Ecto.UUID.generate()
      company_id = Ecto.UUID.generate()
      edge_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      alias EntityRelationshipManager.Domain.Entities.{
        EntityTypeDefinition,
        EdgeTypeDefinition,
        PropertyDefinition
      }

      # Person type includes email so Step 7 (update) can add it
      person_type_with_email =
        EntityTypeDefinition.new(%{
          name: "Person",
          properties: [
            PropertyDefinition.new(%{name: "name", type: :string, required: true}),
            PropertyDefinition.new(%{name: "age", type: :integer, required: false}),
            PropertyDefinition.new(%{name: "email", type: :string, required: false})
          ]
        })

      schema =
        UseCaseFixtures.schema_definition(%{
          workspace_id: ws_id,
          entity_types: [
            person_type_with_email,
            UseCaseFixtures.company_type()
          ],
          edge_types: [
            EdgeTypeDefinition.new(%{
              name: "EMPLOYS",
              properties: [
                PropertyDefinition.new(%{
                  name: "since",
                  type: :datetime,
                  required: false
                }),
                PropertyDefinition.new(%{
                  name: "role",
                  type: :string,
                  required: false,
                  constraints: %{"enum" => ["full-time", "part-time", "contractor"]}
                })
              ]
            })
          ]
        })

      person =
        Entity.new(%{
          id: person_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Alice Johnson", "age" => 30},
          created_at: now,
          updated_at: now
        })

      company =
        Entity.new(%{
          id: company_id,
          workspace_id: ws_id,
          type: "Company",
          properties: %{"name" => "Acme Corp", "founded" => 1990},
          created_at: now,
          updated_at: now
        })

      employs_edge =
        Edge.new(%{
          id: edge_id,
          workspace_id: ws_id,
          type: "EMPLOYS",
          source_id: company_id,
          target_id: person_id,
          properties: %{"role" => "full-time"},
          created_at: now,
          updated_at: now
        })

      updated_person =
        Entity.new(%{
          id: person_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Alice Smith", "age" => 31, "email" => "alice@acme.com"},
          created_at: now,
          updated_at: DateTime.utc_now()
        })

      deleted_person =
        Entity.new(%{
          id: person_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Alice Smith", "age" => 31, "email" => "alice@acme.com"},
          created_at: now,
          updated_at: now,
          deleted_at: DateTime.utc_now()
        })

      # ---------------------------------------------------------------
      # Step 1: PUT schema — define entity types and edge types
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:upsert_schema, fn wid, _attrs ->
        assert wid == ws_id
        {:ok, schema}
      end)

      schema_payload = %{
        "entity_types" => [
          %{
            "name" => "Person",
            "properties" => [
              %{
                "name" => "name",
                "type" => "string",
                "required" => true,
                "constraints" => %{"min_length" => 1, "max_length" => 255}
              },
              %{"name" => "email", "type" => "string", "required" => false},
              %{
                "name" => "age",
                "type" => "integer",
                "required" => false,
                "constraints" => %{"min" => 0, "max" => 200}
              }
            ]
          },
          %{
            "name" => "Company",
            "properties" => [
              %{"name" => "name", "type" => "string", "required" => true},
              %{"name" => "founded", "type" => "integer", "required" => false}
            ]
          }
        ],
        "edge_types" => [
          %{
            "name" => "EMPLOYS",
            "properties" => [
              %{"name" => "since", "type" => "datetime", "required" => false},
              %{
                "name" => "role",
                "type" => "string",
                "required" => false,
                "constraints" => %{"enum" => ["full-time", "part-time", "contractor"]}
              }
            ]
          }
        ]
      }

      resp_conn = put(conn, ~p"/api/v1/workspaces/#{ws_id}/schema", schema_payload)
      assert %{"data" => schema_data} = json_response(resp_conn, 200)
      assert length(schema_data["entity_types"]) == 2
      assert length(schema_data["edge_types"]) == 1

      # ---------------------------------------------------------------
      # Step 2: Create Person entity
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_entity, fn wid, "Person", props ->
        assert wid == ws_id
        assert props["name"] == "Alice Johnson"
        {:ok, person}
      end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice Johnson", "age" => 30}
        })

      assert %{"data" => person_data} = json_response(resp_conn, 201)
      assert person_data["id"] == person_id
      assert person_data["type"] == "Person"
      assert person_data["properties"]["name"] == "Alice Johnson"

      # ---------------------------------------------------------------
      # Step 3: Create Company entity
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_entity, fn wid, "Company", props ->
        assert wid == ws_id
        assert props["name"] == "Acme Corp"
        {:ok, company}
      end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Company",
          "properties" => %{"name" => "Acme Corp", "founded" => 1990}
        })

      assert %{"data" => company_data} = json_response(resp_conn, 201)
      assert company_data["id"] == company_id
      assert company_data["type"] == "Company"

      # ---------------------------------------------------------------
      # Step 4: Create edge (Company EMPLOYS Person)
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, id ->
        assert id == company_id
        {:ok, company}
      end)
      |> expect(:get_entity, fn _wid, id ->
        assert id == person_id
        {:ok, person}
      end)
      |> expect(:create_edge, fn wid, "EMPLOYS", src, tgt, props ->
        assert wid == ws_id
        assert src == company_id
        assert tgt == person_id
        assert props["role"] == "full-time"
        {:ok, employs_edge}
      end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "EMPLOYS",
          "source_id" => company_id,
          "target_id" => person_id,
          "properties" => %{"role" => "full-time"}
        })

      assert %{"data" => edge_data} = json_response(resp_conn, 201)
      assert edge_data["id"] == edge_id
      assert edge_data["type"] == "EMPLOYS"
      assert edge_data["source_id"] == company_id
      assert edge_data["target_id"] == person_id

      # ---------------------------------------------------------------
      # Step 5: Get neighbors of Company -> should include Person
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn wid, eid, _opts ->
        assert wid == ws_id
        assert eid == company_id
        {:ok, [person]}
      end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{company_id}/neighbors")

      assert %{"data" => neighbors} = json_response(resp_conn, 200)
      assert length(neighbors) == 1
      assert hd(neighbors)["id"] == person_id
      assert hd(neighbors)["type"] == "Person"

      # ---------------------------------------------------------------
      # Step 6: Get paths from Person to Company
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:find_paths, fn wid, sid, tid, _opts ->
        assert wid == ws_id
        assert sid == person_id
        assert tid == company_id
        {:ok, [[person_id, company_id]]}
      end)

      resp_conn =
        get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{person_id}/paths/#{company_id}")

      assert %{"data" => paths} = json_response(resp_conn, 200)
      assert length(paths) == 1
      assert hd(paths) == [person_id, company_id]

      # ---------------------------------------------------------------
      # Step 7: Update Person properties
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, id ->
        assert id == person_id
        {:ok, person}
      end)
      |> expect(:update_entity, fn wid, eid, props ->
        assert wid == ws_id
        assert eid == person_id
        assert props["name"] == "Alice Smith"
        {:ok, updated_person}
      end)

      resp_conn =
        put(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{person_id}", %{
          "properties" => %{"name" => "Alice Smith", "age" => 31, "email" => "alice@acme.com"}
        })

      assert %{"data" => updated_data} = json_response(resp_conn, 200)
      assert updated_data["id"] == person_id
      assert updated_data["properties"]["name"] == "Alice Smith"
      assert updated_data["properties"]["email"] == "alice@acme.com"

      # ---------------------------------------------------------------
      # Step 8: Soft-delete Person -> cascading edge soft-delete
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_entity, fn wid, eid ->
        assert wid == ws_id
        assert eid == person_id
        # Returns 1 cascade-deleted edge (the EMPLOYS edge)
        {:ok, deleted_person, 1}
      end)

      resp_conn = delete(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{person_id}")

      assert %{"data" => del_data, "meta" => meta} = json_response(resp_conn, 200)
      assert del_data["id"] == person_id
      assert del_data["deleted_at"] != nil
      assert meta["deleted_edge_count"] == 1

      # ---------------------------------------------------------------
      # Step 9: List entities — verify Company still present
      # ---------------------------------------------------------------
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn wid, _filters ->
        assert wid == ws_id
        # Default listing excludes soft-deleted entities
        {:ok, [company]}
      end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities")

      assert %{"data" => remaining} = json_response(resp_conn, 200)
      assert length(remaining) == 1
      assert hd(remaining)["id"] == company_id
    end

    test "create entity with invalid type returns error", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      # "Organization" does not exist in the schema (only Person, Company)
      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Organization",
          "properties" => %{"name" => "Test Org"}
        })

      assert json_response(resp_conn, 422)
    end

    test "create edge with missing source entity returns error", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})
      source_id = Ecto.UUID.generate()
      target_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _id -> {:error, :not_found} end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => source_id,
          "target_id" => target_id,
          "properties" => %{}
        })

      assert %{"error" => _} = json_response(resp_conn, 422)
    end

    test "schema must be defined before entities can be created", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:error, :not_found} end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice"}
        })

      assert json_response(resp_conn, 404)
    end

    test "edges require valid source and target entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})
      source = UseCaseFixtures.entity(%{workspace_id: ws_id})
      target_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _sid -> {:ok, source} end)
      |> expect(:get_entity, fn _wid, _tid -> {:error, :not_found} end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => source.id,
          "target_id" => target_id,
          "properties" => %{}
        })

      assert %{"error" => _} = json_response(resp_conn, 422)
    end
  end

  describe "bulk operations lifecycle" do
    test "bulk create entities -> bulk create edges -> list all", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :owner)
      now = DateTime.utc_now()

      person1_id = Ecto.UUID.generate()
      person2_id = Ecto.UUID.generate()
      edge_id = Ecto.UUID.generate()

      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      person1 =
        Entity.new(%{
          id: person1_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Alice"},
          created_at: now,
          updated_at: now
        })

      person2 =
        Entity.new(%{
          id: person2_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Bob"},
          created_at: now,
          updated_at: now
        })

      works_at_edge =
        Edge.new(%{
          id: edge_id,
          workspace_id: ws_id,
          type: "WORKS_AT",
          source_id: person1_id,
          target_id: person2_id,
          properties: %{"role" => "Manager"},
          created_at: now,
          updated_at: now
        })

      # Step 1: Bulk create entities
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_entities, fn _wid, entities ->
        assert length(entities) == 2
        {:ok, [person1, person2]}
      end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/bulk", %{
          "entities" => [
            %{"type" => "Person", "properties" => %{"name" => "Alice"}},
            %{"type" => "Person", "properties" => %{"name" => "Bob"}}
          ]
        })

      assert %{"data" => created, "errors" => []} = json_response(resp_conn, 201)
      assert length(created) == 2

      # Step 2: Bulk create edges
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_edges, fn _wid, edges ->
        assert length(edges) == 1
        {:ok, [works_at_edge]}
      end)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/edges/bulk", %{
          "edges" => [
            %{
              "type" => "WORKS_AT",
              "source_id" => person1_id,
              "target_id" => person2_id,
              "properties" => %{"role" => "Manager"}
            }
          ]
        })

      assert %{"data" => edge_list, "errors" => []} = json_response(resp_conn, 201)
      assert length(edge_list) == 1
      assert hd(edge_list)["type"] == "WORKS_AT"

      # Step 3: List all entities
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn _wid, _filters -> {:ok, [person1, person2]} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities")

      assert %{"data" => all_entities} = json_response(resp_conn, 200)
      assert length(all_entities) == 2

      # Step 4: List all edges
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn _wid, _filters -> {:ok, [works_at_edge]} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/edges")

      assert %{"data" => all_edges} = json_response(resp_conn, 200)
      assert length(all_edges) == 1

      # Step 5: Bulk delete
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_soft_delete_entities, fn _wid, ids ->
        assert length(ids) == 2
        {:ok, 2}
      end)

      resp_conn =
        delete(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/bulk", %{
          "entity_ids" => [person1_id, person2_id]
        })

      assert %{"data" => %{"deleted_count" => 2}} = json_response(resp_conn, 200)
    end
  end

  describe "traversal operations" do
    test "traverse graph from a starting entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :member)
      now = DateTime.utc_now()

      start_id = Ecto.UUID.generate()
      hop1_id = Ecto.UUID.generate()
      hop2_id = Ecto.UUID.generate()

      start_entity =
        Entity.new(%{
          id: start_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Root"},
          created_at: now,
          updated_at: now
        })

      hop1 =
        Entity.new(%{
          id: hop1_id,
          workspace_id: ws_id,
          type: "Company",
          properties: %{"name" => "Company A"},
          created_at: now,
          updated_at: now
        })

      hop2 =
        Entity.new(%{
          id: hop2_id,
          workspace_id: ws_id,
          type: "Company",
          properties: %{"name" => "Company B"},
          created_at: now,
          updated_at: now
        })

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:traverse, fn wid, sid, opts ->
        assert wid == ws_id
        assert sid == start_id
        assert Keyword.get(opts, :direction) == "out"
        assert Keyword.get(opts, :max_depth) == 2
        {:ok, [start_entity, hop1, hop2]}
      end)

      resp_conn =
        get(
          conn,
          ~p"/api/v1/workspaces/#{ws_id}/traverse?start_id=#{start_id}&direction=out&max_depth=2"
        )

      assert %{"data" => traversed} = json_response(resp_conn, 200)
      assert length(traversed) == 3
      ids = Enum.map(traversed, & &1["id"])
      assert start_id in ids
      assert hop1_id in ids
      assert hop2_id in ids
    end

    test "get neighbors with edge type filter", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :member)
      entity_id = Ecto.UUID.generate()
      neighbor_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      neighbor =
        Entity.new(%{
          id: neighbor_id,
          workspace_id: ws_id,
          type: "Person",
          properties: %{"name" => "Neighbor"},
          created_at: now,
          updated_at: now
        })

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, eid, opts ->
        assert eid == entity_id
        assert Keyword.get(opts, :edge_type) == "WORKS_AT"
        {:ok, [neighbor]}
      end)

      resp_conn =
        get(
          conn,
          ~p"/api/v1/workspaces/#{ws_id}/entities/#{entity_id}/neighbors?edge_type=WORKS_AT"
        )

      assert %{"data" => neighbors} = json_response(resp_conn, 200)
      assert length(neighbors) == 1
      assert hd(neighbors)["id"] == neighbor_id
    end
  end

  describe "authorization through lifecycle" do
    test "guest cannot create entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice"}
        })

      assert json_response(resp_conn, 403)
    end

    test "guest cannot create edges", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      resp_conn =
        post(conn, ~p"/api/v1/workspaces/#{ws_id}/edges", %{
          "type" => "WORKS_AT",
          "source_id" => Ecto.UUID.generate(),
          "target_id" => Ecto.UUID.generate()
        })

      assert json_response(resp_conn, 403)
    end

    test "guest cannot update entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      entity_id = Ecto.UUID.generate()

      resp_conn =
        put(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{entity_id}", %{
          "properties" => %{"name" => "Bob"}
        })

      assert json_response(resp_conn, 403)
    end

    test "guest cannot delete entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      entity_id = Ecto.UUID.generate()

      resp_conn = delete(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{entity_id}")

      assert json_response(resp_conn, 403)
    end

    test "guest cannot modify schema", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      resp_conn =
        put(conn, ~p"/api/v1/workspaces/#{ws_id}/schema", %{
          "entity_types" => [],
          "edge_types" => []
        })

      assert json_response(resp_conn, 403)
    end

    test "guest CAN read entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn _wid, _filters -> {:ok, []} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities")

      assert json_response(resp_conn, 200)
    end

    test "guest CAN read edges", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn _wid, _filters -> {:ok, []} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/edges")

      assert json_response(resp_conn, 200)
    end

    test "guest CAN read schema", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/schema")

      assert json_response(resp_conn, 200)
    end

    test "guest CAN traverse", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      entity_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, _id, _opts -> {:ok, []} end)

      resp_conn =
        get(conn, ~p"/api/v1/workspaces/#{ws_id}/entities/#{entity_id}/neighbors")

      assert json_response(resp_conn, 200)
    end

    test "member can create and read but not modify schema", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :member)

      # member cannot write schema
      resp_conn =
        put(conn, ~p"/api/v1/workspaces/#{ws_id}/schema", %{
          "entity_types" => [],
          "edge_types" => []
        })

      assert json_response(resp_conn, 403)

      # member CAN read schema
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      resp_conn = get(conn, ~p"/api/v1/workspaces/#{ws_id}/schema")

      assert json_response(resp_conn, 200)
    end
  end
end

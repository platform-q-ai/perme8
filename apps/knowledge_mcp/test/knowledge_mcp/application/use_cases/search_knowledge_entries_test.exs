defmodule KnowledgeMcp.Application.UseCases.SearchKnowledgeEntriesTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Application.UseCases.SearchKnowledgeEntries
  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Mocks.ErmGatewayMock

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  defp entity_with(overrides) do
    erm_knowledge_entity(overrides)
  end

  describe "execute/3" do
    test "searches by keyword query against title and body, returns sorted results" do
      e1 =
        entity_with(%{
          id: "match-title",
          properties: %{
            "title" => "Elixir patterns guide",
            "body" => "Some other content",
            "category" => "pattern",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      e2 =
        entity_with(%{
          id: "match-body",
          properties: %{
            "title" => "Other title",
            "body" => "Content about elixir stuff",
            "category" => "how_to",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      e3 =
        entity_with(%{
          id: "no-match",
          properties: %{
            "title" => "Unrelated",
            "body" => "Nothing relevant",
            "category" => "concept",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, [e1, e2, e3]} end)

      assert {:ok, results} =
               SearchKnowledgeEntries.execute(workspace_id(), %{query: "elixir"},
                 erm_gateway: ErmGatewayMock
               )

      assert length(results) == 2
      # Title match should be first (higher score)
      assert hd(results).id == "match-title"
    end

    test "filters by tags (AND logic)" do
      e1 =
        entity_with(%{
          id: "tagged",
          properties: %{
            "title" => "Tagged entry",
            "body" => "Content",
            "category" => "how_to",
            "tags" => Jason.encode!(["elixir", "testing"]),
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      e2 =
        entity_with(%{
          id: "partial-tag",
          properties: %{
            "title" => "Partial tag",
            "body" => "Content",
            "category" => "how_to",
            "tags" => Jason.encode!(["elixir"]),
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, [e1, e2]} end)

      assert {:ok, results} =
               SearchKnowledgeEntries.execute(workspace_id(), %{tags: ["elixir", "testing"]},
                 erm_gateway: ErmGatewayMock
               )

      assert length(results) == 1
      assert hd(results).id == "tagged"
    end

    test "filters by category" do
      e1 =
        entity_with(%{
          id: "how-to",
          properties: %{
            "title" => "How to test",
            "body" => "Steps...",
            "category" => "how_to",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      e2 =
        entity_with(%{
          id: "concept",
          properties: %{
            "title" => "Concept stuff",
            "body" => "Theory...",
            "category" => "concept",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, [e1, e2]} end)

      assert {:ok, results} =
               SearchKnowledgeEntries.execute(workspace_id(), %{category: "how_to"},
                 erm_gateway: ErmGatewayMock
               )

      assert length(results) == 1
      assert hd(results).id == "how-to"
    end

    test "returns {:error, :empty_search} when no search criteria provided" do
      assert {:error, :empty_search} =
               SearchKnowledgeEntries.execute(workspace_id(), %{}, erm_gateway: ErmGatewayMock)
    end

    test "limits results (default 20, max 100)" do
      entities =
        for i <- 1..25 do
          entity_with(%{
            id: "e-#{i}",
            properties: %{
              "title" => "Entry #{i}",
              "body" => "Content #{i}",
              "category" => "how_to",
              "tags" => "[]",
              "code_snippets" => "[]",
              "file_paths" => "[]",
              "external_links" => "[]",
              "last_verified_at" => nil
            }
          })
        end

      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, entities} end)

      assert {:ok, results} =
               SearchKnowledgeEntries.execute(workspace_id(), %{category: "how_to"},
                 erm_gateway: ErmGatewayMock
               )

      assert length(results) == 20
    end

    test "returns entries as KnowledgeEntry domain objects with snippet" do
      e =
        entity_with(%{
          properties: %{
            "title" => "Test",
            "body" => String.duplicate("a", 300),
            "category" => "how_to",
            "tags" => "[]",
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, [e]} end)

      assert {:ok, [result]} =
               SearchKnowledgeEntries.execute(workspace_id(), %{category: "how_to"},
                 erm_gateway: ErmGatewayMock
               )

      assert %KnowledgeEntry{} = result
      # Body should be truncated (snippet)
      assert String.length(result.body) <= 203
    end

    test "returns {:ok, []} for valid search with no matches" do
      ErmGatewayMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, []} end)

      assert {:ok, []} =
               SearchKnowledgeEntries.execute(workspace_id(), %{query: "nonexistent"},
                 erm_gateway: ErmGatewayMock
               )
    end
  end
end

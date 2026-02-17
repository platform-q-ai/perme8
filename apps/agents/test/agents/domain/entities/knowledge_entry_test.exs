defmodule Agents.Domain.Entities.KnowledgeEntryTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Entities.KnowledgeEntry

  import Agents.Test.KnowledgeFixtures

  describe "new/1" do
    test "creates a struct from valid attrs" do
      attrs = %{
        id: "entry-1",
        workspace_id: workspace_id(),
        title: "How to deploy",
        body: "## Deployment steps...",
        category: "how_to",
        tags: ["devops", "deployment"],
        code_snippets: [%{language: "bash", code: "mix release"}],
        file_paths: ["lib/deploy.ex"],
        external_links: [%{url: "https://example.com"}],
        last_verified_at: ~U[2026-01-15 10:00:00Z],
        created_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      entry = KnowledgeEntry.new(attrs)

      assert entry.id == "entry-1"
      assert entry.workspace_id == workspace_id()
      assert entry.title == "How to deploy"
      assert entry.body == "## Deployment steps..."
      assert entry.category == "how_to"
      assert entry.tags == ["devops", "deployment"]
      assert entry.code_snippets == [%{language: "bash", code: "mix release"}]
      assert entry.file_paths == ["lib/deploy.ex"]
      assert entry.external_links == [%{url: "https://example.com"}]
      assert entry.last_verified_at == ~U[2026-01-15 10:00:00Z]
      assert entry.created_at == ~U[2026-01-01 00:00:00Z]
      assert entry.updated_at == ~U[2026-01-01 00:00:00Z]
    end

    test "sets defaults for optional list fields" do
      entry = KnowledgeEntry.new(%{title: "Minimal", body: "Content", category: "concept"})

      assert entry.tags == []
      assert entry.code_snippets == []
      assert entry.file_paths == []
      assert entry.external_links == []
    end
  end

  describe "from_erm_entity/1" do
    test "converts an ERM Entity with properties into a KnowledgeEntry" do
      erm_entity =
        erm_knowledge_entity(%{
          id: "entity-123",
          workspace_id: "ws-abc",
          properties: %{
            "title" => "Architecture Decisions",
            "body" => "We use Clean Architecture because...",
            "category" => "architecture_decision",
            "tags" => Jason.encode!(["architecture", "design"]),
            "code_snippets" =>
              Jason.encode!([%{"language" => "elixir", "code" => "defmodule Foo"}]),
            "file_paths" => Jason.encode!(["lib/foo.ex"]),
            "external_links" => Jason.encode!([%{"url" => "https://clean.com"}]),
            "last_verified_at" => "2026-01-15T10:00:00Z"
          },
          created_at: ~U[2026-01-01 00:00:00Z],
          updated_at: ~U[2026-01-02 00:00:00Z]
        })

      entry = KnowledgeEntry.from_erm_entity(erm_entity)

      assert entry.id == "entity-123"
      assert entry.workspace_id == "ws-abc"
      assert entry.title == "Architecture Decisions"
      assert entry.body == "We use Clean Architecture because..."
      assert entry.category == "architecture_decision"
      assert entry.tags == ["architecture", "design"]
      assert entry.code_snippets == [%{"language" => "elixir", "code" => "defmodule Foo"}]
      assert entry.file_paths == ["lib/foo.ex"]
      assert entry.external_links == [%{"url" => "https://clean.com"}]
      assert entry.last_verified_at == "2026-01-15T10:00:00Z"
      assert entry.created_at == ~U[2026-01-01 00:00:00Z]
      assert entry.updated_at == ~U[2026-01-02 00:00:00Z]
    end

    test "handles nil/empty JSON-encoded list fields" do
      erm_entity =
        erm_knowledge_entity(%{
          properties: %{
            "title" => "Test",
            "body" => "Body",
            "category" => "concept",
            "tags" => nil,
            "code_snippets" => nil,
            "file_paths" => nil,
            "external_links" => nil,
            "last_verified_at" => nil
          }
        })

      entry = KnowledgeEntry.from_erm_entity(erm_entity)

      assert entry.tags == []
      assert entry.code_snippets == []
      assert entry.file_paths == []
      assert entry.external_links == []
      assert entry.last_verified_at == nil
    end
  end

  describe "to_erm_properties/1" do
    test "converts a KnowledgeEntry to ERM-compatible properties map" do
      entry =
        KnowledgeEntry.new(%{
          title: "Deploy Guide",
          body: "Steps to deploy...",
          category: "how_to",
          tags: ["devops", "ci"],
          code_snippets: [%{language: "bash", code: "mix release"}],
          file_paths: ["lib/deploy.ex"],
          external_links: [%{url: "https://docs.com"}],
          last_verified_at: "2026-02-01T00:00:00Z"
        })

      props = KnowledgeEntry.to_erm_properties(entry)

      assert props["title"] == "Deploy Guide"
      assert props["body"] == "Steps to deploy..."
      assert props["category"] == "how_to"
      assert Jason.decode!(props["tags"]) == ["devops", "ci"]

      assert Jason.decode!(props["code_snippets"]) == [
               %{"language" => "bash", "code" => "mix release"}
             ]

      assert Jason.decode!(props["file_paths"]) == ["lib/deploy.ex"]
      assert Jason.decode!(props["external_links"]) == [%{"url" => "https://docs.com"}]
      assert props["last_verified_at"] == "2026-02-01T00:00:00Z"
    end
  end

  describe "snippet/1" do
    test "returns first 200 chars of body for search result previews" do
      long_body = String.duplicate("a", 300)
      entry = KnowledgeEntry.new(%{body: long_body})

      snippet = KnowledgeEntry.snippet(entry)

      assert String.length(snippet) == 203
      assert String.ends_with?(snippet, "...")
    end

    test "returns full body when body is shorter than 200 chars" do
      entry = KnowledgeEntry.new(%{body: "Short body"})

      snippet = KnowledgeEntry.snippet(entry)

      assert snippet == "Short body"
    end

    test "handles nil body" do
      entry = KnowledgeEntry.new(%{})

      snippet = KnowledgeEntry.snippet(entry)

      assert snippet == ""
    end
  end
end

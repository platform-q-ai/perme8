# Chat with Documents - Implementation Plan

## Overview

This feature will enable users to upload documents (PDFs, Word files, PPTX, XLSX, HTML, images, and more), process them with IBM Docling for enhanced structure extraction, vectorize their content, and chat with them using an LLM. The implementation follows Clean Architecture principles, TDD methodology, and maintains strict boundary enforcement.

**Key Technology: IBM Docling** - An open-source document processing toolkit that uses computer vision models to parse diverse formats into a unified representation, maintaining document structure (layout, reading order, tables, formulas, images) without traditional OCR. Docling is 30x faster than traditional approaches and preserves semantic structure essential for high-quality RAG.

## User Story

As a user, I want to:
1. Upload documents (PDF, DOCX, PPTX, XLSX, HTML, images, audio) to a project or workspace
2. Have documents automatically processed with structure preservation (tables, formulas, images, reading order)
3. Leverage enhanced document understanding for better RAG responses
4. Ask questions about the documents via an LLM chat interface
5. View document metadata (filename, size, upload date, processing status, structure)
6. Delete documents I've uploaded
7. Choose whether a document is converted for retrieval or just stored privately via a checkbox input

## Architecture Overview

### New Context: `Jarga.Documents`

Following the existing pattern of `Accounts`, `Workspaces`, and `Projects`, we'll create a new bounded context for document management.

```
lib/jarga/documents/
├── document.ex                          # Ecto schema (exported)
├── document_structure.ex                # Ecto schema for DoclingDocument JSON
├── documents.ex                         # Public context API
├── domain/
│   ├── entities/
│   │   ├── document_chunk.ex            # In-memory chunk representation
│   │   └── docling_document.ex          # DoclingDocument wrapper
│   └── value_objects/
│       ├── file_metadata.ex             # File type, size, validation
│       ├── document_element.ex          # Text/Table/Picture items
│       └── vector_embedding.ex          # Vector representation
├── policies/
│   ├── upload_policy.ex                 # Validation rules for uploads
│   ├── chunking_policy.ex               # Structure-aware chunking rules
│   └── query_policy.ex                  # Business rules for document queries
├── infrastructure/
│   ├── persistence/
│   │   ├── document_repository.ex       # Data access for documents
│   │   └── vector_store.ex              # Vector database operations
│   ├── docling/
│   │   ├── docling_client.ex            # Python interop for Docling
│   │   ├── document_parser.ex           # Parse DoclingDocument JSON
│   │   └── structure_extractor.ex       # Extract semantic structure
│   ├── retrieval/
│   │   ├── semantic_expander.ex         # Expand chunks to semantic blocks
│   │   └── block_reranker.ex            # Rerank and deduplicate blocks
│   ├── storage/
│   │   └── file_storage.ex              # File system/S3 storage
│   └── services/
│       ├── llm_client.ex                # LLM API integration
│       └── embedding_service.ex         # Generate embeddings
├── use_cases/
│   ├── use_case.ex                      # UseCase behavior
│   ├── upload_document.ex               # Handle file upload & processing
│   ├── process_document.ex              # Docling processing, chunk, vectorize
│   ├── query_documents.ex               # Structure-aware RAG query
│   └── delete_document.ex               # Remove document & vectors
└── queries.ex                           # Query objects for documents
```

### Boundary Configuration

```elixir
# lib/jarga/documents.ex
defmodule Jarga.Documents do
  use Boundary,
    deps: [
      Jarga.Accounts,      # For user ownership
      Jarga.Workspaces,    # For workspace association
      Jarga.Projects,      # For project association (optional)
      Jarga.Repo
    ],
    exports: [{Document, []}]
end
```

Update `JargaWeb` boundary to include `Jarga.Documents` in deps.

## Database Schema

### Documents Table

```elixir
# priv/repo/migrations/TIMESTAMP_create_documents.exs
create table(:documents, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :filename, :string, null: false
  add :original_filename, :string, null: false
  add :file_type, :string, null: false  # "pdf", "docx", "pptx", "xlsx", "html", "image", "audio", etc.
  add :file_size, :integer, null: false  # bytes
  add :storage_path, :string, null: false
  add :mime_type, :string, null: false

  # Processing status
  add :status, :string, null: false, default: "pending"
  # pending, processing, parsed, vectorized, completed, failed
  add :processing_error, :text
  add :processed_at, :utc_datetime

  # Docling structure (stored as JSONB for rich querying)
  add :docling_structure, :jsonb  # Full DoclingDocument representation

  # Metadata extracted from Docling
  add :page_count, :integer
  add :word_count, :integer
  add :table_count, :integer
  add :image_count, :integer
  add :chunk_count, :integer
  add :has_formulas, :boolean, default: false
  add :has_code_blocks, :boolean, default: false

  # Associations
  add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
  add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
  add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)

  timestamps(type: :utc_datetime)
end

create index(:documents, [:user_id])
create index(:documents, [:workspace_id])
create index(:documents, [:project_id])
create index(:documents, [:status])
create index(:documents, [:docling_structure], using: :gin)  # For JSONB queries
```

### Document Chunks Table (for vector embeddings)

```elixir
# priv/repo/migrations/TIMESTAMP_create_document_chunks.exs
create table(:document_chunks, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false

  # Content
  add :content, :text, null: false
  add :chunk_index, :integer, null: false  # Position in document
  add :token_count, :integer

  # Docling-specific metadata (structure-aware)
  add :element_type, :string  # "text", "table", "picture", "code", "formula"
  add :page_number, :integer
  add :section_title, :string
  add :section_level, :integer  # Heading level (h1=1, h2=2, etc.)
  add :parent_section, :string  # Parent section for hierarchical context

  # Table-specific metadata (when element_type = "table")
  add :table_structure, :jsonb  # Structured table data from TableFormer
  add :table_caption, :string

  # Picture-specific metadata (when element_type = "picture")
  add :image_classification, :string  # From Docling's image classifier
  add :image_caption, :string

  # JSON Pointer to original position in DoclingDocument
  add :docling_ref, :string  # e.g., "/body/0/children/2"

  # Vector embedding (pgvector extension)
  add :embedding, :vector, size: 1536  # OpenAI ada-002 dimension

  timestamps(type: :utc_datetime)
end

create index(:document_chunks, [:document_id])
create index(:document_chunks, [:document_id, :chunk_index])
create index(:document_chunks, [:element_type])
create index(:document_chunks, [:table_structure], using: :gin)

# Vector similarity search index (requires pgvector extension)
execute "CREATE INDEX document_chunks_embedding_idx ON document_chunks USING ivfflat (embedding vector_cosine_ops)"
```

### Chat Sessions Table (optional, for conversation history)

```elixir
# priv/repo/migrations/TIMESTAMP_create_chat_sessions.exs
create table(:chat_sessions, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :title, :string
  add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
  add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
  add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)

  timestamps(type: :utc_datetime)
end

create table(:chat_messages, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :chat_session_id, references(:chat_sessions, type: :binary_id, on_delete: :delete_all), null: false
  add :role, :string, null: false  # "user", "assistant", "system"
  add :content, :text, null: false

  # Retrieved context for this message
  add :context_chunks, {:array, :binary_id}, default: []

  timestamps(type: :utc_datetime)
end

create index(:chat_messages, [:chat_session_id])
```

## Dependencies

### Required Hex Packages

```elixir
# mix.exs - Add to deps()
{:pgvector, "~> 0.3.0"},           # PostgreSQL vector extension
{:nx, "~> 0.9"},                   # Numerical computing (for embeddings)
{:openai, "~> 0.6"},               # OpenAI API client (for embeddings only)
{:req, "~> 0.5"},                  # HTTP client for OpenRouter (already in project)
{:tiktoken, "~> 0.1"},             # Token counting for chunking
{:briefly, "~> 0.4"},              # Temporary file handling
{:oban, "~> 2.18"},                # Background job processing
{:jason, "~> 1.4"},                # JSON parsing (already in project)
{:erlport, "~> 0.11"},             # Erlang-Python interop for Docling
```

### Python Dependencies (for Docling)

Docling requires Python 3.10+ with the following packages:

```bash
# Create a Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install Docling
pip install docling
pip install docling-core
pip install docling-ibm-models  # Optional: IBM's vision models

# For specific format support
pip install python-docx  # DOCX
pip install openpyxl     # XLSX
pip install python-pptx  # PPTX
```

### Python Wrapper Script

We'll create a Python script that Elixir calls via ErlPort:

```python
# priv/python/docling_service.py
"""
Python service for processing documents with IBM Docling.
Called from Elixir via ErlPort.
"""
import json
import sys
from pathlib import Path
from docling.document_converter import DocumentConverter

def process_document(file_path: str, output_format: str = "json") -> dict:
    """
    Process a document using Docling and return structured data.

    Args:
        file_path: Path to the document to process
        output_format: Output format (json, markdown, html)

    Returns:
        dict with:
        - success: bool
        - document: DoclingDocument as dict (if success)
        - error: error message (if failure)
    """
    try:
        converter = DocumentConverter()
        result = converter.convert(file_path)

        # Get DoclingDocument
        doc = result.document

        # Convert to different formats
        if output_format == "markdown":
            content = doc.export_to_markdown()
        elif output_format == "html":
            content = doc.export_to_html()
        else:  # json (native format)
            content = doc.export_to_dict()

        return {
            "success": True,
            "document": content,
            "metadata": {
                "page_count": len(doc.pages) if hasattr(doc, 'pages') else None,
                "has_tables": len([item for item in doc.tables]) > 0,
                "has_pictures": len([item for item in doc.pictures]) > 0,
                "text_count": len([item for item in doc.texts]),
            }
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__
        }

def main():
    """Main entry point for ErlPort."""
    for line in sys.stdin:
        try:
            data = json.loads(line)
            command = data.get("command")

            if command == "process_document":
                result = process_document(
                    data["file_path"],
                    data.get("output_format", "json")
                )
                print(json.dumps(result))
                sys.stdout.flush()
            else:
                print(json.dumps({"success": False, "error": "Unknown command"}))
                sys.stdout.flush()
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            sys.stdout.flush()

if __name__ == "__main__":
    main()
```

### PostgreSQL Extension

Enable pgvector in PostgreSQL:

```elixir
# priv/repo/migrations/TIMESTAMP_enable_pgvector.exs
def up do
  execute "CREATE EXTENSION IF NOT EXISTS vector"
end

def down do
  execute "DROP EXTENSION vector"
end
```

## Implementation Phases (TDD Order)

### Phase 1: Domain Layer (Pure Logic)

**Goal**: Define business rules without any I/O

#### 1.1 Value Objects (Test First)

**Test**: `test/jarga/documents/domain/value_objects/file_metadata_test.exs`
```elixir
describe "FileMetadata.new/1" do
  test "accepts valid PDF file"
  test "accepts valid DOCX file"
  test "accepts valid TXT file"
  test "accepts valid MD file"
  test "rejects files over 50MB"
  test "rejects unsupported file types"
  test "extracts correct MIME type"
end
```

**Implement**: `lib/jarga/documents/domain/value_objects/file_metadata.ex`
- Validate file type, size, MIME type
- Pure functions, no I/O

#### 1.2 Policies (Test First)

**Test**: `test/jarga/documents/policies/upload_policy_test.exs`
```elixir
describe "UploadPolicy" do
  test "valid_file_type?/1 returns true for supported types"
  test "valid_file_size?/1 accepts files under limit"
  test "max_file_size/0 returns 50MB"
  test "allowed_extensions/0 returns supported extensions (pdf, docx, pptx, xlsx, html, images)"
  test "supports_docling?/1 checks if file type is Docling-compatible"
end
```

**Implement**: `lib/jarga/documents/policies/upload_policy.ex`
- Business rules for uploads
- Constants (max size, allowed types)
- Docling-compatible file types
- No side effects

**Test**: `test/jarga/documents/policies/chunking_policy_test.exs`
```elixir
describe "ChunkingPolicy" do
  test "chunk_size_for_element/1 returns size based on element type"
  test "should_chunk_table?/1 determines if table needs chunking"
  test "overlap_size/0 returns appropriate overlap"
  test "preserve_structure?/1 checks if element should maintain structure"
  test "chunk_by_section?/1 determines section-based chunking"
end
```

**Implement**: `lib/jarga/documents/policies/chunking_policy.ex`
- Structure-aware chunking rules
- Handle different element types (text, table, code, formula)
- Preserve semantic boundaries
- Token limits per element type

### Phase 2: Infrastructure Layer (Data Access & External Services)

#### 2.1 Database Schema & Repository (Test First)

**Test**: `test/jarga/documents/infrastructure/persistence/document_repository_test.exs`
```elixir
describe "DocumentRepository" do
  test "create/2 inserts document record"
  test "get_by_id/1 retrieves document"
  test "get_for_user/2 returns user's documents"
  test "get_for_workspace/2 returns workspace documents"
  test "update_status/2 updates processing status"
  test "delete/1 removes document and chunks"
end
```

**Implement**:
- Migration files
- `lib/jarga/documents/document.ex` - Ecto schema
- `lib/jarga/documents/infrastructure/persistence/document_repository.ex`

#### 2.2 File Storage (Test First)

**Test**: `test/jarga/documents/infrastructure/storage/file_storage_test.exs`
```elixir
describe "FileStorage" do
  test "store/2 saves file and returns path"
  test "retrieve/1 returns file contents"
  test "delete/1 removes file from storage"
  test "generate_storage_path/1 creates unique path"
  test "file_exists?/1 checks existence"
end
```

**Implement**: `lib/jarga/documents/infrastructure/storage/file_storage.ex`
- Store uploaded files (local filesystem for dev, S3 for prod)
- Generate unique file paths
- Clean up files on document deletion

#### 2.3 Docling Client (Test First)

**Test**: `test/jarga/documents/infrastructure/docling/docling_client_test.exs`
```elixir
describe "DoclingClient" do
  test "process_document/1 returns DoclingDocument structure"
  test "process_document/1 handles PDFs"
  test "process_document/1 handles DOCX files"
  test "process_document/1 handles PPTX files"
  test "process_document/1 handles XLSX files"
  test "process_document/1 handles images"
  test "process_document/1 returns error for corrupted files"
  test "process_document/1 includes metadata"
  test "export_to_markdown/1 converts DoclingDocument"
end
```

**Implement**:
- `lib/jarga/documents/infrastructure/docling/docling_client.ex`
  - Call Python Docling service via ErlPort/Port
  - Parse JSON response into Elixir structs
  - Handle Python process lifecycle
  - Error handling and retries

**Key Functions**:
```elixir
@spec process_document(file_path :: String.t()) ::
  {:ok, docling_document :: map()} | {:error, reason :: term()}

@spec export_to_format(docling_document :: map(), format :: atom()) ::
  {:ok, content :: String.t()} | {:error, reason :: term()}
```

#### 2.4 Document Parser (Test First)

**Test**: `test/jarga/documents/infrastructure/docling/document_parser_test.exs`
```elixir
describe "DocumentParser" do
  test "parse/1 converts DoclingDocument JSON to domain entities"
  test "extract_texts/1 returns all text items"
  test "extract_tables/1 returns table structures"
  test "extract_pictures/1 returns image metadata"
  test "extract_structure/1 returns document hierarchy"
  test "get_reading_order/1 returns elements in reading order"
end
```

**Implement**: `lib/jarga/documents/infrastructure/docling/document_parser.ex`
- Parse DoclingDocument JSON
- Extract texts, tables, pictures
- Maintain document structure (body, furniture, groups)
- Preserve JSON Pointer references

#### 2.5 Structure Extractor (Test First)

**Test**: `test/jarga/documents/infrastructure/docling/structure_extractor_test.exs`
```elixir
describe "StructureExtractor" do
  test "extract_sections/1 identifies document sections"
  test "build_hierarchy/1 creates section tree"
  test "extract_metadata/1 gets page counts, word counts"
  test "classify_elements/1 categorizes text/table/picture/code/formula"
end
```

**Implement**: `lib/jarga/documents/infrastructure/docling/structure_extractor.ex`
- Extract semantic structure
- Build section hierarchy
- Classify content types
- Extract rich metadata

#### 2.6 Embedding Service (Test First)

**Test**: `test/jarga/documents/infrastructure/services/embedding_service_test.exs`
```elixir
describe "EmbeddingService" do
  test "generate_embedding/1 returns vector for text"
  test "generate_embeddings/1 batches multiple texts"
  test "handles rate limiting gracefully"
  test "returns error for empty text"
end
```

**Implement**: `lib/jarga/documents/infrastructure/services/embedding_service.ex`
- Call OpenAI Embeddings API
- Batch processing for efficiency
- Rate limiting/retry logic
- Dependency injection for testing (use Mox)

#### 2.7 Vector Store (Test First)

**Test**: `test/jarga/documents/infrastructure/persistence/vector_store_test.exs`
```elixir
describe "VectorStore" do
  test "store_chunks/2 inserts chunks with embeddings"
  test "similarity_search/3 finds relevant chunks"
  test "delete_chunks_for_document/1 removes all chunks"
  test "get_chunks/2 retrieves chunks by IDs"
end
```

**Implement**: `lib/jarga/documents/infrastructure/persistence/vector_store.ex`
- Store document chunks with embeddings
- Similarity search using pgvector
- Manage chunk lifecycle

#### 2.8 Semantic Expander (Test First)

**Test**: `test/jarga/documents/infrastructure/retrieval/semantic_expander_test.exs`
```elixir
describe "SemanticExpander" do
  test "expand_chunk_to_block/2 expands text chunk to full paragraph"
  test "expand_chunk_to_block/2 expands to full section when appropriate"
  test "expand_chunk_to_block/2 returns complete table for table chunks"
  test "expand_chunk_to_block/2 includes table caption"
  test "expand_chunk_to_block/2 expands list items to complete list"
  test "expand_chunk_to_block/2 expands code snippets to full code block"
  test "expand_chunk_to_block/2 preserves reading order"
  test "expand_chunk_to_block/2 uses docling_ref to navigate structure"
  test "expand_chunk_to_block/2 handles page boundaries"
  test "expand_chunks/2 processes multiple chunks"
  test "expand_chunks/2 maintains chunk-to-block mapping"
end
```

**Implement**: `lib/jarga/documents/infrastructure/retrieval/semantic_expander.ex`
- Use stored DoclingDocument JSON to expand chunks
- Navigate structure using JSON Pointer (docling_ref)
- Identify semantic boundaries (paragraph, section, table, list)
- Extract complete blocks with context
- Preserve document metadata (page, section, hierarchy)
- Return expanded blocks with original chunk mapping

**Key Functions**:
```elixir
@spec expand_chunk_to_block(chunk :: map(), docling_doc :: map()) ::
  {:ok, block :: map()} | {:error, reason :: term()}

@spec expand_chunks(chunks :: [map()], docling_doc :: map()) ::
  {:ok, blocks :: [map()]} | {:error, reason :: term()}
```

#### 2.9 Block Reranker (Test First)

**Test**: `test/jarga/documents/infrastructure/retrieval/block_reranker_test.exs`
```elixir
describe "BlockReranker" do
  test "rerank/2 scores blocks by relevance"
  test "rerank/2 prioritizes by element type"
  test "rerank/2 considers block size"
  test "deduplicate/1 removes overlapping blocks"
  test "deduplicate/1 keeps highest scored block when overlap"
  test "deduplicate/1 preserves reading order"
  test "select_top_blocks/2 returns N best blocks"
  test "select_top_blocks/2 respects token limit"
  test "order_by_document_flow/1 sorts by reading order"
end
```

**Implement**: `lib/jarga/documents/infrastructure/retrieval/block_reranker.ex`
- Rerank expanded blocks by multiple factors
- Detect overlapping content (same page, section)
- Deduplicate intelligently
- Apply token limits
- Maintain reading order

**Reranking Algorithm**:
```elixir
score = (chunk_similarity * 0.5) +
        (element_type_weight * 0.3) +
        (size_preference * 0.2)

# Element type weights (query-dependent)
text: 1.0, table: 0.9, list: 0.8, code: 0.7, image: 0.5
```

#### 2.10 LLM Client (Test First)

**Test**: `test/jarga/documents/infrastructure/services/llm_client_test.exs`
```elixir
describe "LlmClient" do
  test "chat/2 sends messages and returns response via OpenRouter"
  test "chat_with_context/3 includes context in system message"
  test "uses google/gemini-flash-2.5-lite model"
  test "handles streaming responses"
  test "respects token limits"
  test "includes proper OpenRouter headers"
  test "handles rate limiting from OpenRouter"
end
```

**Implement**: `lib/jarga/documents/infrastructure/services/llm_client.ex`
- Call OpenRouter API (compatible with OpenAI format)
- Use Google Gemini Flash 2.5 Lite model
- Format context for RAG
- Stream responses for UI
- Include OpenRouter-specific headers (HTTP-Referer, X-Title)
- Error handling and rate limiting

**OpenRouter Integration**:
```elixir
# Example API call
Req.post!("https://openrouter.ai/api/v1/chat/completions",
  json: %{
    model: "google/gemini-flash-2.5-lite",
    messages: messages
  },
  headers: [
    {"Authorization", "Bearer #{api_key}"},
    {"HTTP-Referer", site_url},
    {"X-Title", app_name}
  ]
)
```

**Benefits of Gemini Flash 2.5 Lite**:
- Very fast response times
- Cost-effective
- Good performance on RAG tasks
- 1M token context window
- Supports streaming

### Phase 3: Application Layer (Use Cases)

#### 3.1 Upload Document Use Case (Test First)

**Test**: `test/jarga/documents/use_cases/upload_document_test.exs`
```elixir
describe "UploadDocument.execute/2" do
  test "validates file metadata"
  test "stores file to storage"
  test "creates document record"
  test "enqueues processing job"
  test "returns error for invalid file type"
  test "returns error for oversized file"
  test "cleans up on failure"
end
```

**Implement**: `lib/jarga/documents/use_cases/upload_document.ex`
- Validate using UploadPolicy
- Store file via FileStorage
- Create document record via Repository
- Enqueue background processing job
- Transaction boundary

#### 3.2 Process Document Use Case (Test First)

**Test**: `test/jarga/documents/use_cases/process_document_test.exs`
```elixir
describe "ProcessDocument.execute/2" do
  test "processes document with Docling"
  test "stores DoclingDocument structure in database"
  test "extracts semantic structure (sections, hierarchy)"
  test "chunks text with structure awareness"
  test "preserves table structures separately"
  test "handles images and formulas"
  test "generates embeddings for chunks"
  test "stores chunks with element metadata in vector store"
  test "updates document status through pipeline"
  test "handles Docling processing failures gracefully"
  test "updates status to failed on error"
end
```

**Implement**: `lib/jarga/documents/use_cases/process_document.ex`
- Process document via DoclingClient
- Store full DoclingDocument JSON in database
- Parse structure via DocumentParser
- Extract semantic elements via StructureExtractor
- Chunk with structure awareness (ChunkingPolicy)
- Generate embeddings via EmbeddingService
- Store chunks with rich metadata in VectorStore
- Update document status through pipeline
- Runs as Oban background job

**Processing Pipeline**:
1. **Parse**: Call Docling → Get DoclingDocument
2. **Store Structure**: Save full JSON to database
3. **Extract**: Parse elements (texts, tables, pictures)
4. **Chunk**: Structure-aware chunking
5. **Embed**: Generate embeddings
6. **Index**: Store in vector store
7. **Complete**: Update status

#### 3.3 Query Documents Use Case (RAG with Semantic Block Retrieval) (Test First)

**Test**: `test/jarga/documents/use_cases/query_documents_test.exs`
```elixir
describe "QueryDocuments.execute/2" do
  # Stage 1: Retrieval
  test "generates embedding for query"
  test "retrieves top K relevant chunks via similarity search"

  # Stage 2: Semantic Expansion
  test "expands chunks to semantic blocks (full paragraphs, sections, tables)"
  test "uses Docling structure to identify block boundaries"
  test "expands table chunks to complete table"
  test "expands text chunks to full section or page"
  test "preserves reading order from Docling"

  # Stage 3: Reranking (optional)
  test "reranks expanded blocks by relevance"
  test "prioritizes blocks by element type for query context"
  test "removes redundant overlapping blocks"

  # Stage 4: Context Assembly
  test "deduplicates overlapping content"
  test "orders blocks by document flow"
  test "includes structural context (section, hierarchy)"
  test "handles table-specific queries with structured data"
  test "formats rich context for LLM with metadata"

  # LLM & Response
  test "calls LLM with expanded context"
  test "returns answer with detailed source attribution"
  test "includes page numbers, sections, and block references"
  test "provides full source blocks for user verification"
  test "handles no relevant chunks found"
  test "respects user permissions"
  test "respects token limits (Gemini 1M context)"
end
```

**Implement**: `lib/jarga/documents/use_cases/query_documents.ex`

**Two-Stage Retrieval + Semantic Expansion Strategy**:

1. **Stage 1: Chunk Retrieval** (Precise)
   - Generate query embedding
   - Similarity search for top K chunks (K=10-20)
   - Fast, focused retrieval

2. **Stage 2: Semantic Expansion** (Context)
   - For each retrieved chunk, expand to semantic block:
     - **Paragraph** → Full paragraph
     - **Section** → Full section (or first page if section is very long)
     - **Table** → Complete table with caption
     - **List** → Complete list
     - **Code block** → Complete code block
     - **Formula** → Surrounding context (paragraph)
   - Use Docling's `docling_ref` (JSON Pointer) to navigate structure
   - Preserve Docling reading order

3. **Stage 3: Reranking** (Quality)
   - Score expanded blocks by:
     - Original chunk similarity score
     - Element type relevance (text > tables > images for most queries)
     - Block size (prefer concise blocks when possible)
     - Document importance (if multiple docs)
   - Deduplicate overlapping blocks (keep highest scored)
   - Select top N blocks (N=3-5 depending on size)

4. **Stage 4: Context Assembly** (LLM Input)
   - Order blocks by document reading order
   - Format with rich metadata
   - Include document hierarchy
   - Stay within token limits (Gemini has 1M context!)

5. **Stage 5: LLM Query**
   - Call LLM with assembled context
   - Stream response

6. **Stage 6: Response with Sources**
   - Return answer
   - Include source blocks (user can view full context)
   - Provide precise attribution (doc, page, section, element)

**Enhanced Context Format** (Semantic Blocks):
```
Document: example.pdf

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Document: example.pdf | Page 2 | Section: Introduction]

Introduction

This document presents our quarterly results for Q1 and Q2.
The introduction provides context for the analysis that follows,
explaining the methodology and key metrics tracked during this period.
Our focus was on revenue growth and market expansion.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Document: example.pdf | Page 5 | Section: Results | Table: "Quarterly Results"]

Table 1: Quarterly Financial Results

| Quarter | Revenue | Growth | Customers |
|---------|---------|--------|-----------|
| Q1 2024 | $100K   | 10%    | 1,200     |
| Q2 2024 | $120K   | 20%    | 1,500     |

The table shows strong growth in both revenue and customer acquisition
across the two quarters analyzed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Document: example.pdf | Page 8 | Section: Conclusion]

Conclusion

In conclusion, our performance exceeded expectations with consistent
growth across all metrics. The 20% revenue growth in Q2 demonstrates
strong market demand and effective execution of our strategy.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Response Format**:
```elixir
%{
  answer: "Based on the quarterly results...",
  sources: [
    %{
      document_id: "doc-123",
      document_name: "example.pdf",
      page: 5,
      section: "Results",
      element_type: "table",
      element_title: "Quarterly Results",
      content: "Full table content...",
      chunk_id: "chunk-456",  # Original chunk that matched
      relevance_score: 0.89
    },
    %{
      document_id: "doc-123",
      document_name: "example.pdf",
      page: 2,
      section: "Introduction",
      element_type: "text",
      content: "Full introduction section...",
      chunk_id: "chunk-123",
      relevance_score: 0.76
    }
  ],
  metadata: %{
    chunks_retrieved: 15,
    blocks_expanded: 15,
    blocks_after_dedup: 8,
    blocks_sent_to_llm: 3,
    total_tokens: 2500,
    processing_time_ms: 850
  }
}
```

#### 3.4 Delete Document Use Case (Test First)

**Test**: `test/jarga/documents/use_cases/delete_document_test.exs`
```elixir
describe "DeleteDocument.execute/2" do
  test "verifies user ownership"
  test "deletes vector chunks"
  test "deletes file from storage"
  test "deletes document record"
  test "returns error if not found"
  test "returns error if not authorized"
end
```

**Implement**: `lib/jarga/documents/use_cases/delete_document.ex`
- Verify user has permission (owner or workspace admin)
- Delete from VectorStore
- Delete from FileStorage
- Delete document record
- Transaction boundary

### Phase 4: Context Public API

**Test**: `test/jarga/documents_test.exs`
```elixir
describe "Documents context" do
  test "upload_document/3 uploads and processes document"
  test "list_documents/2 returns user's documents"
  test "list_workspace_documents/2 returns workspace docs"
  test "get_document/2 retrieves document"
  test "query_documents/3 performs RAG query"
  test "delete_document/2 removes document"
  test "get_processing_status/1 returns status"
end
```

**Implement**: `lib/jarga/documents/documents.ex`
- Delegate to use cases
- Clean public API with type specs
- Documentation with examples
- Consistent error tuples

### Phase 5: Interface Layer (LiveView)

#### 5.1 Document Upload LiveView (Test First)

**Test**: `test/jarga_web/live/documents_live/index_test.exs`
```elixir
describe "DocumentsLive.Index" do
  test "renders upload form"
  test "shows document list"
  test "uploads file on submit"
  test "shows upload progress"
  test "displays processing status"
  test "allows deletion"
  test "shows errors on invalid file"
  test "requires authentication"
  test "filters by workspace"
  test "filters by project"
end
```

**Implement**: `lib/jarga_web/live/documents_live/index.ex`
- Use `allow_upload/3` for file handling
- Configure accepted types, max size
- Display upload progress
- Show processing status per document
- Handle validation errors
- Delete functionality
- Filter by workspace/project

**Route**: `/app/workspaces/:workspace_id/documents` or `/app/projects/:project_id/documents`

#### 5.2 Global Chat Panel Component (Test First)

**Test**: `test/jarga_web/live/chat_live/panel_test.exs`
```elixir
describe "ChatLive.Panel (LiveComponent)" do
  # Panel state
  test "renders collapsed by default"
  test "expands when toggle clicked"
  test "persists state in localStorage"
  test "closes on Escape key"

  # Document selection
  test "shows workspace documents when on workspace page"
  test "shows project documents when on project page"
  test "auto-filters documents by context"
  test "allows manual document selection"
  test "disables input when no documents selected"

  # Chat functionality
  test "sends message and receives response"
  test "streams LLM responses in real-time"
  test "displays source blocks below answer"
  test "expands source blocks on click"
  test "shows full semantic blocks in expanded view"
  test "handles no relevant sources"
  test "shows error messages"

  # Real-time updates
  test "updates when new documents uploaded"
  test "updates processing status in real-time"
  test "handles WebSocket disconnection gracefully"

  # State management
  test "preserves chat history across navigation"
  test "loads previous session on mount"
  test "creates new session on 'New conversation'"
end
```

**Implement**: `lib/jarga_web/live/chat_live/panel.ex`
- LiveView component (not full LiveView)
- Embedded in root layout (`app.html.heex`)
- State management (collapsed/expanded, selected docs, messages)
- Context-aware document filtering
- WebSocket streaming for LLM responses
- Phoenix.PubSub for real-time updates
- LocalStorage integration via hooks

**Key Functions**:
```elixir
# Mount with initial state
def mount(socket) do
  # Subscribe to workspace/project document updates
  # Load user's documents
  # Restore session from localStorage (via hook)
end

# Toggle panel
def handle_event("toggle_panel", _params, socket)

# Select/deselect documents
def handle_event("toggle_document", %{"doc_id" => id}, socket)

# Send query
def handle_event("send_message", %{"message" => text}, socket) do
  # Call Documents.query_documents/3
  # Stream response via handle_info
end

# Handle streaming chunks from LLM
def handle_info({:llm_chunk, chunk}, socket)

# Handle document processing updates
def handle_info({:document_updated, doc}, socket)
```

#### 5.3 Chat Panel Sub-Components

**Test**: `test/jarga_web/live/chat_live/components/*_test.exs`

**Implement**:

1. **Document Selector Component**
   ```elixir
   # lib/jarga_web/live/chat_live/components/document_selector.ex
   def document_selector(assigns) do
     # Render document list with checkboxes
     # Show processing status
     # Filter controls
   end
   ```

2. **Message Component**
   ```elixir
   # lib/jarga_web/live/chat_live/components/message.ex
   def message(assigns) do
     # Render user or assistant message
     # Show timestamp
     # Action buttons (copy, regenerate, feedback)
   end
   ```

3. **Source Block Component**
   ```elixir
   # lib/jarga_web/live/chat_live/components/source_block.ex
   def source_block(assigns) do
     # Render compact or expanded view
     # Format tables/code with syntax highlighting
     # "View in Document" link
   end
   ```

4. **Message Input Component**
   ```elixir
   # lib/jarga_web/live/chat_live/components/message_input.ex
   def message_input(assigns) do
     # Textarea with auto-resize
     # Send button with loading state
     # Keyboard shortcuts (Cmd+Enter)
   end
   ```

#### 5.4 Root Layout Integration

**Update**: `lib/jarga_web/components/layouts/app.html.heex`
```elixir
<div class="flex h-screen overflow-hidden">
  <!-- Main content area -->
  <div id="main-content" class="flex-1 overflow-auto">
    <!-- Header with chat toggle button -->
    <header class="bg-white shadow">
      <div class="flex justify-between items-center px-4 py-3">
        <div><!-- Logo, workspace selector --></div>
        <button
          phx-click="toggle_chat"
          phx-target="#global-chat-panel"
          class="chat-toggle"
        >
          💬 Chat
        </button>
      </div>
    </header>

    <!-- Page content -->
    <main class="p-6">
      <%= @inner_content %>
    </main>
  </div>

  <!-- Global chat panel -->
  <.live_component
    module={JargaWeb.ChatLive.Panel}
    id="global-chat-panel"
    current_user={@current_user}
    current_workspace={@current_workspace}
    current_project={@current_project}
  />
</div>
```

#### 5.5 JavaScript Hooks for Chat Panel

**File**: `assets/js/chat_hooks.js`
```javascript
// LocalStorage persistence
export const ChatPanel = {
  mounted() {
    // Load collapsed state
    const collapsed = localStorage.getItem('chat_collapsed') === 'true'
    this.pushEvent('restore_state', { collapsed })

    // Load selected documents
    const selectedDocs = JSON.parse(
      localStorage.getItem('chat_selected_docs') || '[]'
    )
    this.pushEvent('restore_selected_docs', { doc_ids: selectedDocs })

    // Listen for state changes
    this.handleEvent('save_state', ({ collapsed, selected_docs }) => {
      localStorage.setItem('chat_collapsed', collapsed)
      localStorage.setItem('chat_selected_docs', JSON.stringify(selected_docs))
    })

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.pushEvent('toggle_panel')
      }
    })
  }
}

// Auto-scroll to latest message
export const ChatMessages = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

#### 5.6 Mobile Fallback (Full-page Chat)

For mobile devices, provide a full-page chat view:

**Route**: `/app/chat` (mobile only, redirects to panel on desktop)

**Test**: `test/jarga_web/live/chat_live/mobile_test.exs`

**Implement**: `lib/jarga_web/live/chat_live/mobile.ex`
- Full-screen chat interface
- Back button to return to previous page
- Same functionality as panel
- Optimized for touch interactions

### Phase 6: Background Jobs (Oban)

**Implement**: `lib/jarga/documents/workers/process_document_worker.ex`
```elixir
defmodule Jarga.Documents.Workers.ProcessDocumentWorker do
  use Oban.Worker, queue: :documents, max_attempts: 3

  def perform(%Oban.Job{args: %{"document_id" => id}}) do
    Documents.process_document(id)
  end
end
```

**Configure Oban**:
```elixir
# config/config.exs
config :jarga, Oban,
  repo: Jarga.Repo,
  queues: [default: 10, documents: 5],
  plugins: [Oban.Plugins.Pruner]
```

## Configuration

### Environment Variables

```bash
# config/runtime.exs or .env
OPENAI_API_KEY=sk-...                              # For embeddings
OPENROUTER_API_KEY=sk-or-...                       # For LLM chat
EMBEDDING_MODEL=text-embedding-ada-002             # OpenAI embeddings
CHAT_MODEL=google/gemini-flash-2.5-lite            # Via OpenRouter
OPENROUTER_SITE_URL=https://yourapp.com            # Optional: for rankings
OPENROUTER_APP_NAME=Jarga                          # Optional: for rankings
MAX_CHUNK_SIZE=1000
CHUNK_OVERLAP=200
VECTOR_SEARCH_LIMIT=5
UPLOAD_MAX_SIZE_MB=50
```

### Application Config

```elixir
# config/config.exs
config :jarga, Jarga.Documents,
  storage_backend: Jarga.Documents.Infrastructure.Storage.FileStorage,
  storage_path: "priv/static/uploads",
  allowed_types: ~w(.pdf .docx .pptx .xlsx .html .png .jpg .jpeg .gif .mp3 .wav),
  max_file_size: 50 * 1024 * 1024,  # 50 MB
  chunk_size: 1000,
  chunk_overlap: 200,
  embedding_model: "text-embedding-ada-002",
  chat_model: "google/gemini-flash-2.5-lite",  # Via OpenRouter
  vector_search_limit: 5,
  # Docling configuration
  docling_python_path: ".venv/bin/python",
  docling_script_path: "priv/python/docling_service.py",
  docling_timeout: 300_000  # 5 minutes

# OpenAI for embeddings
config :jarga, :openai,
  api_key: System.get_env("OPENAI_API_KEY")

# OpenRouter for LLM chat
config :jarga, :openrouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  base_url: "https://openrouter.ai/api/v1",
  site_url: System.get_env("OPENROUTER_SITE_URL"),
  app_name: System.get_env("OPENROUTER_APP_NAME", "Jarga")
```

## Security Considerations

1. **File Upload Validation**
   - Validate MIME type server-side (don't trust client)
   - Scan for malware (integrate ClamAV if needed)
   - Sanitize filenames
   - Limit file size strictly

2. **Authorization**
   - Verify user owns/has access to workspace before upload
   - Check permissions before document access
   - Prevent information leakage via embeddings

3. **API Keys**
   - Store OpenAI API key securely (env vars, secrets manager) - used for embeddings only
   - Store OpenRouter API key securely - used for LLM chat
   - Don't expose keys in client-side code
   - Rate limit API calls (both OpenAI and OpenRouter)

4. **Data Privacy**
   - Ensure documents are scoped to users/workspaces
   - Don't share embeddings across tenants
   - Consider encryption at rest for sensitive documents

## Why Docling? Key Advantages

### 1. **Superior Document Understanding**
- **Structure Preservation**: Maintains document hierarchy, reading order, and layout
- **Table Intelligence**: TableFormer AI model converts tables to structured data (not just text)
- **Formula Recognition**: Identifies and preserves mathematical formulas
- **Image Classification**: Categorizes images (figures, charts, diagrams)
- **Code Block Detection**: Recognizes code blocks separately from text

### 2. **Performance**
- **30x Faster**: Computer vision approach avoids slow OCR
- **Batch Processing**: Handles multiple documents efficiently
- **Local Processing**: No external API calls for parsing (only embeddings/LLM)

### 3. **Format Support**
- **Universal**: PDF, DOCX, PPTX, XLSX, HTML, images, audio
- **Consistent Output**: All formats → unified DoclingDocument representation
- **Future-Proof**: Easy to add new formats via Docling updates

### 4. **Better RAG Quality**
- **Semantic Chunking**: Respect document structure (sections, paragraphs)
- **Context-Aware**: Include section hierarchy in embeddings
- **Element-Specific**: Search tables differently than text
- **Source Attribution**: Precise references (page, section, element type)

### 5. **Open Source & Privacy**
- **No Vendor Lock-in**: IBM open-source project
- **Local Execution**: Process sensitive documents on-premises
- **Transparent**: Full control over processing pipeline

## Why Semantic Block Retrieval? Key Benefits

### 1. **Complete Context**
- Users see **full paragraphs, sections, or tables** - not fragments
- LLM gets proper context around matching text
- Reduces confusion from mid-sentence chunks

### 2. **Better LLM Understanding**
- Full semantic blocks provide coherent context
- Tables remain intact (rows aren't split)
- Section hierarchy preserved
- Formulas shown with surrounding explanation

### 3. **User Verification**
- Users can **read the full source** to verify answers
- Source blocks are self-contained and readable
- Click to view in original document (future enhancement)
- Trust through transparency

### 4. **Docling Advantage**
- Docling already knows semantic boundaries!
- Use `docling_ref` to navigate structure
- No guessing where sections start/end
- Preserves document author's intent

### 5. **Flexible Context**
- Can adjust expansion level (paragraph vs section vs page)
- Gemini's 1M context window allows larger blocks
- Balance between precision and context
- Reranking removes redundancy

### 6. **Better Source Attribution**
```
Instead of:
"...revenue growth of 20%..." (fragment)

Users see:
"Table 1: Quarterly Results
| Q1 | $100K | 10% |
| Q2 | $120K | 20% |
The table shows strong growth..."
(complete, verifiable source)
```

## Performance Considerations

1. **Background Processing**
   - Process documents asynchronously via Oban
   - Docling processing can take 1-5 minutes for large PDFs
   - Update status in real-time via LiveView
   - Handle failures with retries
   - Queue priority: small docs first

2. **Docling Optimization**
   - Use Python process pool for parallel processing
   - Cache DoclingDocument JSON in database
   - Reprocess only if source file changes
   - Consider Docling Granite model for faster results (smaller footprint)

3. **Chunking Strategy**
   - **Structure-aware**: Chunk by sections, not arbitrary token limits
   - **Preserve tables**: Keep tables as single chunks (don't split)
   - **Overlap at boundaries**: Only overlap between sections
   - **Element-specific sizes**: Smaller chunks for code, larger for text

4. **Vector Search**
   - Index embeddings properly (ivfflat)
   - **Hybrid search**: Combine similarity + element type filtering
   - Tune search limit (K parameter) based on query type
   - Cache frequently accessed chunks
   - Pre-filter by workspace/project before similarity search

5. **LLM Calls**
   - Stream responses for better UX (Gemini Flash supports streaming)
   - Implement timeouts (30s for queries)
   - Handle rate limits gracefully (OpenRouter provides rate limit headers)
   - **Context windowing**: Include only most relevant chunks
   - **Cost efficiency**: Gemini Flash 2.5 Lite is very cost-effective via OpenRouter
   - **Large context**: 1M token context window for long documents
   - Monitor costs via OpenRouter dashboard

## Testing Strategy

Following TDD principles:

### Test Pyramid
1. **Domain Layer** (Fast, Pure)
   - Value objects, policies
   - No database, no external APIs
   - ExUnit.Case

2. **Infrastructure Layer** (Slower, I/O)
   - Repositories, extractors, services
   - Use Mox for external services
   - Jarga.DataCase for database

3. **Application Layer** (Orchestration)
   - Use cases with mocked dependencies
   - Test transaction boundaries
   - Jarga.DataCase + Mox

4. **Interface Layer** (End-to-End)
   - LiveView tests
   - User interactions
   - JargaWeb.ConnCase

### Mock Strategy

```elixir
# test/support/mocks.ex
Mox.defmock(Jarga.Documents.Infrastructure.Services.EmbeddingServiceMock,
  for: Jarga.Documents.Infrastructure.Services.EmbeddingServiceBehaviour)

Mox.defmock(Jarga.Documents.Infrastructure.Services.LlmClientMock,
  for: Jarga.Documents.Infrastructure.Services.LlmClientBehaviour)
```

Use Mox to avoid calling external APIs in tests.

## UI/UX Design

### Documents Index Page
- Table view with columns: Filename, Type, Size, Status, Uploaded, Actions
- Upload button/drag-and-drop zone
- Processing status indicators (pending, processing, completed, failed)
- Delete button per document
- Filter by status, type
- Search by filename

### Chat Interface: Global Collapsible Right Panel

**Architecture**: Chat lives in the root layout as a globally accessible LiveView component

**Layout**: Collapsible right-hand panel accessible from any logged-in page

```
┌──────────────────────────────────────────────────────────────────────┐
│ 🏠 Jarga | Workspace: My Team        [User Menu]     💬 Chat [Open] │
├──────────────────────────────────────────────────────┬───────────────┤
│                                                      │               │
│  Main Content Area                                   │  CHAT PANEL   │
│  (Dashboard, Projects, Settings, etc.)               │  (Collapsed)  │
│                                                      │               │
│  User is on /app/workspaces/workspace-123           │   [Expand →]  │
│  or /app/projects/proj-456                          │               │
│  or any other app page...                           │               │
│                                                      │               │
└──────────────────────────────────────────────────────┴───────────────┘
```

**When Expanded** (slide-in from right, 400px width):

```
┌──────────────────────────────────────────────────────┬───────────────┐
│ 🏠 Jarga | Workspace: My Team        [User Menu]     │  💬 Chat      │
├──────────────────────────────────────────────────────┼───────────────┤
│                                                      │ [← Close]     │
│  Main Content Area (compressed)                      │               │
│                                                      │ 📚 Documents  │
│                                                      │ ┌───────────┐ │
│  Content reflows to accommodate chat panel           │ │☑ report   │ │
│                                                      │ │☑ data.xlsx│ │
│                                                      │ │☐ notes    │ │
│                                                      │ │[Select All]│ │
│                                                      │ └───────────┘ │
│                                                      │               │
│                                                      │ 💬 Chat       │
│                                                      │ ┌───────────┐ │
│                                                      │ │User: Q2?  │ │
│                                                      │ │           │ │
│                                                      │ │AI: 20%... │ │
│                                                      │ │📄 Sources │ │
│                                                      │ └───────────┘ │
│                                                      │               │
│                                                      │ Ask...  [Send]│
└──────────────────────────────────────────────────────┴───────────────┘
```

**Mobile/Tablet**: Full-screen overlay when opened

```
┌──────────────────────────────────────┐
│ [← Back] Chat with Documents         │
├──────────────────────────────────────┤
│                                      │
│  📚 Documents                        │
│  ☑ report.pdf  ☑ data.xlsx          │
│                                      │
│  💬 Chat History                     │
│  ┌────────────────────────────────┐ │
│  │ User: What was Q2 growth?      │ │
│  │                                │ │
│  │ AI: Based on the results...    │ │
│  │                                │ │
│  │ 📄 Sources (2)                 │ │
│  │ [Tap to expand]                │ │
│  └────────────────────────────────┘ │
│                                      │
│  💬 Ask a question...        [Send] │
└──────────────────────────────────────┘
```

### Implementation Details

#### 1. **Root Layout Component**
```elixir
# lib/jarga_web/components/layouts/app.html.heex
<div class="flex h-screen">
  <!-- Main content area -->
  <div class="flex-1 overflow-auto">
    <%= @inner_content %>
  </div>

  <!-- Global chat panel (LiveView component) -->
  <.live_component
    module={JargaWeb.ChatLive.Panel}
    id="global-chat-panel"
    current_user={@current_user}
    current_workspace={@current_workspace}
  />
</div>
```

#### 2. **Chat Panel LiveView Component**
```elixir
# lib/jarga_web/live/chat_live/panel.ex
defmodule JargaWeb.ChatLive.Panel do
  use JargaWeb, :live_component

  # State
  # - collapsed: boolean (default true)
  # - selected_documents: list of document IDs
  # - messages: chat history
  # - current_query: string
  # - streaming: boolean
end
```

#### 3. **State Management**
- **Panel state** persisted in browser localStorage:
  - `collapsed: true/false`
  - `selected_documents: [ids]`
  - `last_session_id: uuid`
- **Chat history** stored in database (chat_sessions table)
- **LiveView handles**:
  - WebSocket connection for streaming
  - Real-time updates
  - Document selection changes

#### 4. **Context-Aware Document Selection**

The chat panel automatically filters documents based on current context:

**User on Workspace page** (`/app/workspaces/workspace-123`):
```
📚 Documents (Workspace: My Team)
☑ All workspace documents
  - report.pdf (Project A)
  - data.xlsx (Project B)
  - strategy.docx (Workspace)
```

**User on Project page** (`/app/projects/proj-456`):
```
📚 Documents (Project: Project Alpha)
☑ Project documents
  - design.pdf
  - specs.docx
☐ Include workspace documents (5 more)
```

**User on Dashboard** (`/app/dashboard`):
```
📚 Documents (All Workspaces)
Select workspace: [Dropdown]
☑ My Team workspace docs
```

#### 5. **Panel Features**

**Header**:
- "💬 Chat with Documents" title
- Close button (← or X)
- Settings/options menu (⋮)
  - New conversation
  - View all conversations
  - Settings
  - Help

**Document Selector** (Collapsible section):
- Auto-filter by current workspace/project
- Checkboxes for document selection
- Processing status indicators
- Quick filters:
  - "All" / "Only current project" / "Only current workspace"
  - File type filter (PDF, DOCX, etc.)
- Document count: "5 documents selected"
- "Select All" / "Clear All" buttons

**Chat Area**:
- Scrollable message history
- Auto-scroll to latest message
- User messages (right-aligned, colored)
- Assistant messages (left-aligned)
- Streaming responses with typing indicator (...)
- Timestamps (relative: "2 min ago")

**Source Blocks** (Below each answer):
- Compact cards (default):
  - Icon (📄 text, 📊 table, 📷 image, 📝 code)
  - `document.pdf, Page 5 • Results`
  - First line of content...
  - `[Expand ↓]`
- Expanded view:
  - Full semantic block
  - Formatted tables/code
  - Metadata footer
  - `[View in Document →]` (navigates to document page)
  - `[Collapse ↑]`

**Message Input**:
- Textarea with placeholder: "Ask about your documents..."
- Multi-line support (Shift+Enter)
- Send button (Cmd/Ctrl+Enter or click)
- Disable when no documents selected
- Loading state during query

**Actions per Message**:
- Copy answer (📋)
- Regenerate (🔄)
- Feedback (👍 👎)
- Share (🔗) - future

**Footer**:
- Token usage indicator (optional): "~2.5K tokens"
- "Clear chat" button
- "Export conversation" (future)

### 6. **Technical Implementation**

#### LiveView Component Structure
```
lib/jarga_web/live/chat_live/
├── panel.ex                    # Main panel LiveView component
├── panel.html.heex             # Panel template
├── components/
│   ├── document_selector.ex    # Document selection UI
│   ├── message.ex              # Individual message component
│   ├── source_block.ex         # Source citation card
│   └── message_input.ex        # Chat input component
└── panel_live.ex               # Full-page chat (mobile fallback)
```

#### State Synchronization
- Panel state synced via Phoenix.PubSub
- Subscribe to workspace/project document updates
- Real-time processing status updates
- LiveView `handle_info/2` for streaming responses

#### CSS Classes (Tailwind)
```css
/* Panel container */
.chat-panel {
  @apply fixed right-0 top-0 h-screen w-96 bg-white shadow-2xl;
  @apply transform transition-transform duration-300 ease-in-out;
  @apply z-50;
}

.chat-panel.collapsed {
  @apply translate-x-full;
}

.chat-panel.expanded {
  @apply translate-x-0;
}

/* Toggle button (when collapsed) */
.chat-toggle {
  @apply fixed right-0 top-20 bg-blue-600 text-white;
  @apply px-4 py-2 rounded-l-lg shadow-lg;
  @apply cursor-pointer hover:bg-blue-700;
}
```

#### Keyboard Shortcuts
- `Cmd/Ctrl + K`: Toggle chat panel
- `Cmd/Ctrl + Enter`: Send message
- `Escape`: Close panel
- `/`: Focus message input

### 7. **User Experience Benefits**

✅ **Always Accessible**: Ask questions from any page
✅ **Context-Aware**: Auto-filters documents by current workspace/project
✅ **Non-Disruptive**: Main content stays visible
✅ **Persistent**: Chat history survives navigation
✅ **Fast**: No page reload, instant toggle
✅ **Responsive**: Adapts to mobile (full-screen overlay)

### 8. **Example User Flows**

**Flow 1: Quick Question from Dashboard**
1. User on `/app/dashboard`
2. Clicks "💬 Chat" button in header
3. Panel slides in from right
4. Workspace documents auto-selected
5. Types "What's our Q2 revenue?"
6. Gets answer with sources
7. Closes panel, stays on dashboard

**Flow 2: Deep Dive on Project**
1. User on `/app/projects/proj-123`
2. Chat panel already open (persisted state)
3. Only project documents selected
4. Asks multiple related questions
5. Expands source blocks to read full context
6. Clicks "View in Document" to see PDF
7. Returns to project page, chat still open

**Flow 3: Cross-Workspace Research**
1. User on `/app/workspaces`
2. Opens chat
3. Selects "All workspaces"
4. Picks specific documents from multiple workspaces
5. Asks comparative questions
6. Exports conversation as Markdown
7. Shares link with team

## Migration Strategy

### Development
1. Enable pgvector extension
2. Run migrations
3. Configure environment variables
4. Install dependencies
5. Start with local file storage

### Production
1. Use S3/object storage for files
2. Separate storage bucket per environment
3. Monitor OpenAI API usage/costs
4. Set up Oban dashboard for job monitoring
5. Configure proper background job concurrency

## Future Enhancements

### Phase 2 Features (Post-MVP)
- [ ] Document summarization
- [ ] Collaborative chat (multiple users)
- [ ] Export chat history
- [ ] Document versioning
- [ ] Advanced search filters
- [ ] Citation generation
- [ ] Multi-language support
- [ ] Cost tracking per user/workspace
- [ ] Custom embedding models (open-source)
- [ ] Hybrid search (keyword + semantic)

### Scalability Enhancements
- [ ] Dedicated vector database (Pinecone, Weaviate, Qdrant)
- [ ] Distributed task processing
- [ ] Caching layer (Redis)
- [ ] CDN for file delivery
- [ ] Horizontal scaling for Oban workers

## Success Metrics

- Document upload success rate > 99%
- Processing time < 2 minutes for 20-page PDF
- Query response time < 5 seconds
- Answer relevance (user feedback) > 80%
- System uptime > 99.9%

## Timeline Estimate

Following TDD, implementing one layer at a time:

- **Phase 1** (Domain): 2-3 days
- **Phase 2** (Infrastructure): 5-7 days
- **Phase 3** (Application): 3-4 days
- **Phase 4** (Context API): 1-2 days
- **Phase 5** (LiveView): 4-5 days
- **Phase 6** (Background Jobs): 1-2 days
- **Testing & Polish**: 2-3 days

**Total: 18-26 days** (3.5-5 weeks for one developer)

Can be parallelized by having different developers work on:
- Document upload flow
- Chat/RAG flow
- Infrastructure services

## References

- [Phoenix LiveView Uploads](https://hexdocs.pm/phoenix_live_view/uploads.html)
- [Boundary Library](https://hexdocs.pm/boundary)
- [Pgvector](https://github.com/pgvector/pgvector)
- [OpenAI Embeddings API](https://platform.openai.com/docs/guides/embeddings)
- [RAG Architecture Patterns](https://www.pinecone.io/learn/retrieval-augmented-generation/)
- [Chunking Strategies](https://www.pinecone.io/learn/chunking-strategies/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

## Getting Started

Once this plan is approved, start with:

1. **Create new git branch**: `git checkout -b chat-with-docs` ✅ (Already done)
2. **Add dependencies** to `mix.exs`
3. **Enable pgvector** migration
4. **Write first test** in domain layer (FileMetadata)
5. **Follow TDD cycle**: Red → Green → Refactor
6. **Commit after each green cycle**

Remember: **Write tests first, always!**

---

## Summary: Technology Stack

### Document Processing: IBM Docling
- **Why**: Superior structure extraction (30x faster than OCR)
- **Formats**: PDF, DOCX, PPTX, XLSX, HTML, images, audio
- **Output**: Unified DoclingDocument with preserved structure
- **Integration**: Python service called via ErlPort from Elixir

### Vector Database: PostgreSQL + pgvector
- **Why**: Leverage existing PostgreSQL infrastructure
- **Capability**: Similarity search with cosine distance
- **Index**: IVFFlat for fast retrieval
- **Scale**: Can handle millions of embeddings

### Embeddings: OpenAI text-embedding-ada-002
- **Why**: Industry-standard, high-quality embeddings
- **Dimension**: 1536
- **Cost**: ~$0.0001 per 1K tokens
- **Performance**: Fast, reliable

### LLM Chat: Google Gemini Flash 2.5 Lite (via OpenRouter)
- **Why**: Fast, cost-effective, excellent for RAG
- **Context**: 1M tokens (perfect for long documents)
- **Speed**: Near-instant responses
- **Cost**: Very affordable via OpenRouter
- **Streaming**: Full support for real-time responses
- **Integration**: OpenAI-compatible API format

### Background Jobs: Oban
- **Why**: Robust, persistent job queue built for Elixir
- **Features**: Retries, priorities, scheduling
- **Use case**: Async document processing

### Real-time UI: Phoenix LiveView
- **Why**: Already in stack, perfect for file uploads
- **Features**: Live upload progress, streaming chat responses
- **Benefits**: No separate frontend needed

## Architecture Benefits

1. **Best-in-class document understanding** (Docling)
2. **Cost-effective LLM** (Gemini Flash via OpenRouter)
3. **Simple infrastructure** (PostgreSQL + pgvector, no separate vector DB)
4. **Local document processing** (Docling runs locally, privacy-first)
5. **Clean Architecture** (TDD, boundary enforcement, testable)
6. **Scalable** (Oban workers, database indexes, background processing)

## Cost Estimate (per 1000 documents)

Assuming average document: 20 pages, 10K tokens

**Processing Cost**:
- Docling: $0 (runs locally)
- Embeddings: ~$1 (10K tokens × 1000 docs × $0.0001/1K tokens)
- LLM queries: ~$0.10 per 1000 queries (Gemini Flash is very cheap)

**Total**: ~$1-2 per 1000 documents processed + minimal query costs

**Compared to alternatives**:
- Azure Document Intelligence: ~$10-15 per 1000 docs
- AWS Textract: ~$15-20 per 1000 docs
- GPT-4 for chat: 10-20x more expensive than Gemini Flash

## Next Steps

1. **Review and approve this plan**
2. **Set up Python environment** for Docling
3. **Create OpenRouter account** and get API key
4. **Start TDD implementation** with Domain layer
5. **Iterate through phases** following Red-Green-Refactor

Ready to build an enterprise-grade document chat system! 🚀

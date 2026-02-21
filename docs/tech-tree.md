# Perme8 Tech Tree

A capability progression showing how each piece of the platform unlocks the next
tier. Build from the bottom up -- completing a level gates access to the next.

Items in **bold** are gate prerequisites annotated with which level they unlock.

---

## Level 0 -- Foundation

> A working collaborative editing app. The seed of everything.

```mermaid
graph LR
    JARGA["<b>jarga</b><br/><i>Core Domain</i><br/>Workspaces, Projects, Documents,<br/>Notes, Notifications<br/>PostgreSQL, PubSub, EventBus"]
    JARGA_WEB["<b>jarga_web</b><br/><i>Browser Application</i><br/>Phoenix LiveView UI,<br/>CRDT collaborative editing,<br/>real-time dashboards"]

    JARGA -->|"domain logic"| JARGA_WEB

    classDef l0 fill:#4a9eff,stroke:#2563eb,color:#fff,stroke-width:2px
    class JARGA,JARGA_WEB l0
```

| App | What It Provides | Gate? |
|-----|-----------------|-------|
| **jarga** | Core domain logic: workspaces, projects, documents, notes, notifications. Owns PostgreSQL, PubSub, EventBus, Mailer. | Both required to unlock Level 1 |
| **jarga_web** | Phoenix LiveView browser UI with CRDT collaborative document editing and real-time dashboards. | Both required to unlock Level 1 |

---

## Level 1 -- Framework

> Modularise. Add testing infrastructure, chat, and AI capabilities.

```mermaid
graph BT
    %% Level 0 (prerequisites)
    JARGA["<b>jarga</b><br/><i>L0</i>"]:::l0
    JARGA_WEB["<b>jarga_web</b><br/><i>L0</i>"]:::l0

    %% Level 1 (unlocked)
    PERME8["<b>perme8</b><br/><i>Umbrella Orchestration</i><br/>Shared config, boundary enforcement,<br/>monorepo structure,<br/>coordinated releases"]:::l1
    EXO_BDD["<b>exo-bdd</b><br/><i>BDD Test Framework</i><br/>Cucumber + Playwright + ZAP,<br/>HTTP / Browser / CLI /<br/>Graph / Security adapters"]:::l1
    CHAT["<b>chat</b><br/><i>Real-time Messaging</i><br/>Chat sessions, message threads,<br/>PubSub-driven, workspace-scoped"]:::l1
    AGENTS["<b>agents</b><br/><i>AI Agent Orchestration</i><br/>Agent CRUD, LLM integration,<br/>MCP protocol, tool execution"]:::l1

    JARGA -->|"enables modularisation"| PERME8
    JARGA_WEB -->|"needs test coverage"| EXO_BDD
    JARGA -->|"provides PubSub &amp; data"| CHAT
    JARGA -->|"provides data layer"| AGENTS

    classDef l0 fill:#4a9eff,stroke:#2563eb,color:#fff,stroke-width:2px
    classDef l1 fill:#8b5cf6,stroke:#7c3aed,color:#fff,stroke-width:2px
```

| App | What It Provides | Gate? |
|-----|-----------------|-------|
| **perme8** | Umbrella shell: shared config, compile-time boundary enforcement, dependency management, coordinated releases. | Required to unlock Level 2 |
| **exo-bdd** | BDD test framework: Cucumber.js + Playwright + OWASP ZAP with HTTP, Browser, CLI, Graph, and Security adapters. | Required to unlock Level 3 |
| **chat** | Real-time messaging: chat sessions, message threads, PubSub-driven, workspace-scoped. | -- |
| **agents** | AI agent orchestration: agent definitions, LLM integration (OpenRouter), MCP protocol tools, tool execution engine. | -- |

---

## Level 2 -- Modularisation

> Extract bounded contexts into isolated apps. Add APIs, graph storage, containers.

```mermaid
graph BT
    %% Level 0 (prerequisites)
    JARGA["<b>jarga</b><br/><i>L0</i>"]:::l0

    %% Level 1 (prerequisites)
    PERME8["<b>perme8</b><br/><i>L1</i>"]:::l1
    AGENTS["<b>agents</b><br/><i>L1</i>"]:::l1

    %% Level 2 (unlocked)
    IDENTITY["<b>identity</b><br/><i>Authentication &amp; RBAC</i><br/>Registration, login, sessions,<br/>multi-tenancy, API keys,<br/>membership &amp; roles"]:::l2
    JARGA_API["<b>jarga_api</b><br/><i>REST API (Documents)</i><br/>JSON API for workspaces,<br/>projects &amp; documents,<br/>API-key authenticated"]:::l2
    AGENTS_API["<b>agents_api</b><br/><i>REST API (Agents)</i><br/>Agent CRUD, query execution,<br/>MCP skills, OpenAPI 3.0 spec"]:::l2
    ERM["<b>entity_relationship_manager</b><br/><i>Knowledge Graph</i><br/>Schema-driven entities &amp; edges,<br/>Neo4j traversal,<br/>tenant-isolated graph API"]:::l2
    CONTAINERS["<b>containers</b><br/><i>Ephemeral Runtimes</i><br/>Docker coding sessions,<br/>sandboxed agent execution,<br/>opencode integration"]:::l2
    SKILLS["<b>skills</b><br/><i>Agent Skills</i><br/>Reusable skill definitions,<br/>tool composition,<br/>prompt orchestration"]:::l2
    TOOLS["<b>perme8_tools</b><br/><i>Dev Tooling</i><br/>BDD step linter, behaviour checker,<br/>boundary scaffolding,<br/>exo-bdd runner, CI sync"]:::l2

    PERME8 -->|"unlocks bounded contexts"| IDENTITY
    PERME8 -->|"unlocks bounded contexts"| JARGA_API
    PERME8 -->|"unlocks bounded contexts"| AGENTS_API
    PERME8 -->|"unlocks bounded contexts"| ERM
    PERME8 -->|"unlocks bounded contexts"| CONTAINERS
    AGENTS -->|"needs skill system"| SKILLS
    PERME8 -->|"enables dev tooling"| TOOLS
    JARGA -->|"domain logic"| JARGA_API

    classDef l0 fill:#4a9eff,stroke:#2563eb,color:#fff,stroke-width:2px
    classDef l1 fill:#8b5cf6,stroke:#7c3aed,color:#fff,stroke-width:2px
    classDef l2 fill:#f59e0b,stroke:#d97706,color:#fff,stroke-width:2px
```

| App | What It Provides | Gate? |
|-----|-----------------|-------|
| **identity** | Extracted auth boundary: user registration, login (password + magic link), sessions, RBAC membership, workspace multi-tenancy, API key management. | Required to unlock Level 3 |
| **jarga_api** | JSON REST API for programmatic access to workspaces, projects, and documents. | -- |
| **agents_api** | JSON REST API for agent management: CRUD, query execution, MCP skill listing, OpenAPI 3.0 spec. | -- |
| **entity_relationship_manager** | Schema-driven knowledge graph backed by Neo4j. Tenant-isolated entities, edges, traversal, bulk operations. | -- |
| **containers** | Ephemeral Docker runtimes for sandboxed agent coding sessions (opencode integration). | -- |
| **skills** | Reusable agent skill definitions, tool composition, and prompt orchestration patterns. | -- |
| **perme8_tools** | Dev-time Mix tasks: BDD step linter, behaviour checker, boundary scaffolding, exo-bdd runner, CI sync. | -- |

---

## Level 3 -- Productionisation

> Lock it down. Security hardening across all external surfaces.

```mermaid
graph BT
    %% Level 1 (prerequisite)
    EXO_BDD["<b>exo-bdd</b><br/><i>L1</i>"]:::l1

    %% Level 2 (prerequisites)
    IDENTITY["<b>identity</b><br/><i>L2</i>"]:::l2
    AGENTS_API["<b>agents_api</b><br/><i>L2</i>"]:::l2
    ERM["<b>ERM</b><br/><i>L2</i>"]:::l2

    %% Level 3 (unlocked)
    SEC_AGENTS["<b>secure agents</b><br/><i>Agent Security</i><br/>API key auth, rate limiting,<br/>input validation, OWASP scans,<br/>sandboxed execution"]:::l3
    SEC_CHAT["<b>secure chat</b><br/><i>Chat Security</i><br/>Auth-gated sessions,<br/>message sanitisation,<br/>XSS / injection prevention"]:::l3
    SEC_ERM["<b>secure ERM</b><br/><i>Graph Security</i><br/>Tenant isolation enforcement,<br/>API key auth, query validation,<br/>OWASP ZAP scans"]:::l3

    IDENTITY -->|"provides auth layer"| SEC_AGENTS
    IDENTITY -->|"provides auth layer"| SEC_CHAT
    IDENTITY -->|"provides auth layer"| SEC_ERM
    EXO_BDD -->|"security test adapters"| SEC_AGENTS
    EXO_BDD -->|"security test adapters"| SEC_CHAT
    EXO_BDD -->|"security test adapters"| SEC_ERM
    AGENTS_API -->|"surface to secure"| SEC_AGENTS
    ERM -->|"surface to secure"| SEC_ERM

    classDef l1 fill:#8b5cf6,stroke:#7c3aed,color:#fff,stroke-width:2px
    classDef l2 fill:#f59e0b,stroke:#d97706,color:#fff,stroke-width:2px
    classDef l3 fill:#ef4444,stroke:#dc2626,color:#fff,stroke-width:2px
```

| Capability | What It Provides | Unlocked By |
|------------|-----------------|-------------|
| **secure agents** | Production-hardened agent API: API key authentication, rate limiting, input validation, OWASP security scans, sandboxed execution. | identity + exo-bdd |
| **secure chat** | Production-hardened chat: auth-gated sessions, message sanitisation, XSS and injection prevention. | identity + exo-bdd |
| **secure ERM** | Production-hardened knowledge graph: tenant isolation enforcement, API key auth, query validation, OWASP ZAP scans. | identity + exo-bdd |

---

## Level 4 -- Graphs

> Structured knowledge. Map what you know and what you build.

```mermaid
graph BT
    %% Level 2 (prerequisite)
    ERM["<b>ERM</b><br/><i>L2</i>"]:::l2

    %% Level 3 (prerequisite)
    SEC_ERM["<b>secure ERM</b><br/><i>L3</i>"]:::l3

    %% Level 4 (unlocked)
    KB["<b>knowledge base</b><br/><i>Workspace Knowledge</i><br/>Entity graphs per workspace,<br/>semantic relationships,<br/>agent-queryable memory"]:::l4
    CODE_STRUCT["<b>code structure</b><br/><i>Codebase Graph</i><br/>Module dependency mapping,<br/>boundary visualisation,<br/>architectural analysis"]:::l4

    ERM -->|"graph storage engine"| KB
    ERM -->|"graph storage engine"| CODE_STRUCT
    SEC_ERM -->|"secured access"| KB
    SEC_ERM -->|"secured access"| CODE_STRUCT

    classDef l2 fill:#f59e0b,stroke:#d97706,color:#fff,stroke-width:2px
    classDef l3 fill:#ef4444,stroke:#dc2626,color:#fff,stroke-width:2px
    classDef l4 fill:#ec4899,stroke:#db2777,color:#fff,stroke-width:2px
```

| Capability | What It Provides | Unlocked By |
|------------|-----------------|-------------|
| **knowledge base** | Workspace-scoped knowledge graphs: entity relationships, semantic connections, agent-queryable structured memory. | ERM + secure ERM |
| **code structure** | Codebase-as-a-graph: module dependency mapping, boundary visualisation, architectural analysis via Neo4j. | ERM + secure ERM |

---

## Level 5 -- Observability

> See what's happening. Measure everything.

```mermaid
graph BT
    %% Level 0 (prerequisite)
    JARGA_WEB["<b>jarga_web</b><br/><i>L0</i>"]:::l0

    %% Level 4 (prerequisite)
    KB["<b>knowledge base</b><br/><i>L4</i>"]:::l4
    CODE_STRUCT["<b>code structure</b><br/><i>L4</i>"]:::l4

    %% Level 5 (unlocked)
    DASHBOARD["<b>dashboard framework</b><br/><i>LiveView Dashboards</i><br/>Composable widget system,<br/>real-time metric panels,<br/>customisable layouts"]:::l5
    LOGGING["<b>logging</b><br/><i>Structured Logging</i><br/>Centralised log aggregation,<br/>contextual trace IDs,<br/>searchable event streams"]:::l5
    MONITORING["<b>monitoring</b><br/><i>System Monitoring</i><br/>Health checks, uptime tracking,<br/>resource utilisation,<br/>alerting &amp; thresholds"]:::l5
    TRACING["<b>tracing</b><br/><i>Distributed Tracing</i><br/>Request lifecycle tracking,<br/>cross-app span correlation,<br/>OpenTelemetry integration"]:::l5

    JARGA_WEB -->|"LiveView foundation"| DASHBOARD
    KB -->|"feeds into"| DASHBOARD
    CODE_STRUCT -->|"feeds into"| DASHBOARD
    DASHBOARD -->|"visualises"| LOGGING
    DASHBOARD -->|"visualises"| MONITORING
    DASHBOARD -->|"visualises"| TRACING

    classDef l0 fill:#4a9eff,stroke:#2563eb,color:#fff,stroke-width:2px
    classDef l4 fill:#ec4899,stroke:#db2777,color:#fff,stroke-width:2px
    classDef l5 fill:#14b8a6,stroke:#0d9488,color:#fff,stroke-width:2px
```

| Capability | What It Provides | Unlocked By |
|------------|-----------------|-------------|
| **dashboard framework** | Composable LiveView widget system: real-time metric panels, customisable layouts, pluggable data sources. | jarga_web + knowledge base + code structure |
| **logging** | Structured, centralised log aggregation with contextual trace IDs and searchable event streams. | dashboard framework |
| **monitoring** | System health checks, uptime tracking, resource utilisation metrics, alerting and thresholds. | dashboard framework |
| **tracing** | Distributed request tracing: cross-app span correlation, request lifecycle tracking, OpenTelemetry integration. | dashboard framework |

---

## Level 6 -- Composition

> Agents that act. Documents that think. The platform as a tool.

```mermaid
graph BT
    %% Level 1 (prerequisites)
    CHAT["<b>chat</b><br/><i>L1</i>"]:::l1
    AGENTS["<b>agents</b><br/><i>L1</i>"]:::l1

    %% Level 4 (prerequisite)
    KB["<b>knowledge base</b><br/><i>L4</i>"]:::l4

    %% Level 5 (prerequisite)
    DASHBOARD["<b>dashboard framework</b><br/><i>L5</i>"]:::l5

    %% Level 6 (unlocked)
    AGENTIC_CHAT["<b>agentic chat</b><br/><i>AI-Powered Chat</i><br/>Agents participate in conversations,<br/>tool use mid-thread,<br/>context-aware responses"]:::l6
    AGENTIC_DOCS["<b>agentic documents</b><br/><i>AI-Powered Documents</i><br/>Agents edit collaboratively,<br/>auto-summarisation,<br/>knowledge extraction"]:::l6
    PERME8_TOOL["<b>perme8 as a tool</b><br/><i>Platform-as-MCP</i><br/>Entire platform exposed as<br/>an MCP tool server,<br/>external agent integration"]:::l6

    CHAT -->|"conversation engine"| AGENTIC_CHAT
    AGENTS -->|"agent capabilities"| AGENTIC_CHAT
    KB -->|"contextual knowledge"| AGENTIC_CHAT
    AGENTS -->|"agent capabilities"| AGENTIC_DOCS
    KB -->|"knowledge extraction"| AGENTIC_DOCS
    AGENTS -->|"agent capabilities"| PERME8_TOOL
    KB -->|"queryable knowledge"| PERME8_TOOL
    DASHBOARD -->|"observable platform"| PERME8_TOOL

    classDef l1 fill:#8b5cf6,stroke:#7c3aed,color:#fff,stroke-width:2px
    classDef l4 fill:#ec4899,stroke:#db2777,color:#fff,stroke-width:2px
    classDef l5 fill:#14b8a6,stroke:#0d9488,color:#fff,stroke-width:2px
    classDef l6 fill:#f97316,stroke:#ea580c,color:#fff,stroke-width:2px
```

| Capability | What It Provides | Unlocked By |
|------------|-----------------|-------------|
| **agentic chat** | AI agents participate in conversations: tool use mid-thread, context-aware responses, knowledge-backed answers. | chat + agents + knowledge base |
| **agentic documents** | AI agents as document collaborators: auto-summarisation, knowledge extraction, collaborative editing. | agents + knowledge base |
| **perme8 as a tool** | The entire platform exposed as an MCP tool server: external agents can query, create, and manage workspaces, projects, documents, knowledge, and agents programmatically. | agents + knowledge base + dashboard framework |

---

## Full Overview

```mermaid
graph BT
    %% L0 - Foundation
    JARGA["<b>jarga</b>"]:::l0
    JARGA_WEB["<b>jarga_web</b>"]:::l0

    %% L1 - Framework
    PERME8["<b>perme8</b>"]:::l1
    EXO_BDD["<b>exo-bdd</b>"]:::l1
    CHAT["<b>chat</b>"]:::l1
    AGENTS["<b>agents</b>"]:::l1

    %% L2 - Modularisation
    IDENTITY["<b>identity</b>"]:::l2
    JARGA_API["<b>jarga_api</b>"]:::l2
    AGENTS_API["<b>agents_api</b>"]:::l2
    ERM["<b>ERM</b>"]:::l2
    CONTAINERS["<b>containers</b>"]:::l2
    SKILLS["<b>skills</b>"]:::l2
    TOOLS["<b>perme8_tools</b>"]:::l2

    %% L3 - Productionisation
    SEC_AGENTS["<b>secure agents</b>"]:::l3
    SEC_CHAT["<b>secure chat</b>"]:::l3
    SEC_ERM["<b>secure ERM</b>"]:::l3

    %% L4 - Graphs
    KB["<b>knowledge base</b>"]:::l4
    CODE_STRUCT["<b>code structure</b>"]:::l4

    %% L5 - Observability
    DASHBOARD["<b>dashboard framework</b>"]:::l5
    LOGGING["<b>logging</b>"]:::l5
    MONITORING["<b>monitoring</b>"]:::l5
    TRACING["<b>tracing</b>"]:::l5

    %% L6 - Composition
    AGENTIC_CHAT["<b>agentic chat</b>"]:::l6
    AGENTIC_DOCS["<b>agentic documents</b>"]:::l6
    PERME8_TOOL["<b>perme8 as a tool</b>"]:::l6

    %% L0 -> L1
    JARGA --> PERME8
    JARGA_WEB --> EXO_BDD
    JARGA --> CHAT
    JARGA --> AGENTS

    %% L1 -> L2
    PERME8 --> IDENTITY
    PERME8 --> JARGA_API
    PERME8 --> AGENTS_API
    PERME8 --> ERM
    PERME8 --> CONTAINERS
    AGENTS --> SKILLS
    PERME8 --> TOOLS

    %% L2 -> L3
    IDENTITY --> SEC_AGENTS
    IDENTITY --> SEC_CHAT
    IDENTITY --> SEC_ERM
    EXO_BDD --> SEC_AGENTS
    EXO_BDD --> SEC_CHAT
    EXO_BDD --> SEC_ERM

    %% L3 -> L4
    ERM --> KB
    ERM --> CODE_STRUCT
    SEC_ERM --> KB
    SEC_ERM --> CODE_STRUCT

    %% L4 -> L5
    JARGA_WEB --> DASHBOARD
    KB --> DASHBOARD
    CODE_STRUCT --> DASHBOARD
    DASHBOARD --> LOGGING
    DASHBOARD --> MONITORING
    DASHBOARD --> TRACING

    %% L5 -> L6
    CHAT --> AGENTIC_CHAT
    AGENTS --> AGENTIC_CHAT
    KB --> AGENTIC_CHAT
    AGENTS --> AGENTIC_DOCS
    KB --> AGENTIC_DOCS
    AGENTS --> PERME8_TOOL
    KB --> PERME8_TOOL
    DASHBOARD --> PERME8_TOOL

    classDef l0 fill:#4a9eff,stroke:#2563eb,color:#fff,stroke-width:2px
    classDef l1 fill:#8b5cf6,stroke:#7c3aed,color:#fff,stroke-width:2px
    classDef l2 fill:#f59e0b,stroke:#d97706,color:#fff,stroke-width:2px
    classDef l3 fill:#ef4444,stroke:#dc2626,color:#fff,stroke-width:2px
    classDef l4 fill:#ec4899,stroke:#db2777,color:#fff,stroke-width:2px
    classDef l5 fill:#14b8a6,stroke:#0d9488,color:#fff,stroke-width:2px
    classDef l6 fill:#f97316,stroke:#ea580c,color:#fff,stroke-width:2px
```

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| **Backend** | Elixir 1.17+, Phoenix 1.8, Phoenix LiveView 1.1, Ecto, Bandit |
| **Frontend** | TypeScript, Tailwind CSS 4, esbuild, Heroicons |
| **Databases** | PostgreSQL 16+ (primary), Neo4j 5+ (graph) |
| **AI/LLM** | OpenRouter API, Hermes MCP (JSON-RPC 2.0 / StreamableHTTP) |
| **Auth** | Bcrypt, session cookies, API keys (SHA256-hashed) |
| **Testing** | ExUnit, Mox, Cucumber/Gherkin, Playwright, OWASP ZAP |
| **Architecture** | Clean Architecture, `boundary` lib (compile-time enforcement) |
| **Infra** | Docker (PostgreSQL, ZAP, opencode sessions), GitHub Actions CI |

# Perme8

A collaborative workspace platform built as an Elixir Phoenix umbrella project. Perme8 provides multi-tenant workspaces with role-based access control, project and document management, AI agent integration, real-time features, a REST API for programmatic access, and a schema-driven graph data layer for knowledge graphs.

## Architecture

Perme8 follows **Clean Architecture** principles throughout, with compile-time boundary enforcement via the [`boundary`](https://hex.pm/packages/boundary) library. Each umbrella app is organized into domain, application, infrastructure, and interface layers, with strict dependency rules enforced at compile time.

```
                    identity (authentication)
                        ^
                        |
                      jarga (core domain)
                     ^  ^  ^
                    /   |   \
                   /    |    \
         jarga_web  jarga_api  entity_relationship_manager
         (browser)  (REST API)       (graph API)

         alkali (standalone static site generator)
          perme8_tools (development tooling)
```

## Umbrella Apps

| App | Description | Port |
|-----|-------------|------|
| [`identity`](apps/identity/) | Self-contained authentication and identity management | 4001 |
| [`jarga`](apps/jarga/) | Core domain logic -- workspaces, projects, documents, agents, chat | -- |
| [`jarga_web`](apps/jarga_web/) | Phoenix LiveView browser interface | 4000 |
| [`jarga_api`](apps/jarga_api/) | JSON REST API for external integrations | -- |
| [`entity_relationship_manager`](apps/entity_relationship_manager/) | Schema-driven graph data layer backed by Neo4j and PostgreSQL | 4005 |
| [`alkali`](apps/alkali/) | Static site generator (standalone, publishable to Hex) | -- |
| [`perme8_tools`](apps/perme8_tools/) | Development-time Mix tasks and linters | -- |

## Prerequisites

- Elixir 1.17+
- Erlang/OTP 27+
- PostgreSQL 16+
- Neo4j 5+ (optional, for entity_relationship_manager graph operations)
- Node.js 20+ (for TypeScript assets and exo-bdd tests)

## Getting Started

```bash
# Clone the repository
git clone git@github.com:platform-q-ai/perme8.git
cd perme8

# Install dependencies
mix deps.get

# Create and migrate databases
mix ecto.setup

# Install Node.js dependencies (for assets and TypeScript tests)
npm install --prefix tools/exo-bdd

# Start the Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) for the web interface and [`localhost:4001`](http://localhost:4001) for the identity service.

## Development

### Running Tests

```bash
# Run the full test suite
mix test

# Run tests for a specific app
mix test apps/jarga/test
mix test apps/identity/test

# Run with coverage
mix test --cover
```

### Pre-commit Checks

The project includes a comprehensive pre-commit alias that runs all quality checks:

```bash
mix precommit
```

This runs:
1. `mix compile --warnings-as-errors` -- strict compilation
2. `mix format --check-formatted` -- code formatting
3. `mix credo` -- static analysis
4. `mix boundary` -- architectural boundary enforcement
5. `mix step_linter` -- BDD step definition linting
6. TypeScript tests via npm
7. Full test suite

### Code Quality

```bash
# Format code
mix format

# Run Credo (static analysis)
mix credo

# Check architectural boundaries
mix boundary
```

### BDD Testing

The project uses Cucumber/Gherkin for behaviour-driven testing, with a TypeScript-based exo-bdd framework supporting multiple adapters:

- **HTTP** -- REST API testing via Playwright
- **Browser** -- UI testing via Playwright
- **CLI** -- command-line testing via Bun
- **Graph** -- Neo4j graph assertions
- **Security** -- vulnerability scanning via ZAP

See [`tools/exo-bdd/README.md`](tools/exo-bdd/README.md) for details.

## Project Principles

- **Tests first** -- always write tests before implementation
- **Boundary enforcement** -- `mix boundary` catches architectural violations at compile time
- **SOLID principles** -- single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion
- **Clean Architecture** -- Domain > Application > Infrastructure > Interface
- **RBAC** -- role-based access control with Owner, Admin, Member, and Guest roles

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/umbrella_apps.md`](docs/umbrella_apps.md) | Guide to umbrella project structure |
| [`docs/architecture/bounded_context_structure.md`](docs/architecture/bounded_context_structure.md) | Clean Architecture pattern reference |
| [`docs/PERMISSIONS.md`](docs/PERMISSIONS.md) | RBAC permission system and role matrices |
| [`docs/BOUNDARY_QUICK_REFERENCE.md`](docs/BOUNDARY_QUICK_REFERENCE.md) | Boundary enforcement quick reference |
| [`docs/TEST_DATABASE.md`](docs/TEST_DATABASE.md) | PostgreSQL test database setup |

# Umbrella Applications in Elixir

Umbrella applications are a way to organize multiple Elixir applications within a single project structure. This is particularly useful for large projects where you want to maintain clear boundaries between different parts of the system while still being able to develop and deploy them together.

## Project Structure

When you create an umbrella project (e.g., via `mix new my_project --umbrella`), the following structure is generated:

```text
my_project/
  apps/
    app_one/
      lib/
      mix.exs
      test/
    app_two/
      lib/
      mix.exs
      test/
  config/
    config.exs
  mix.exs
```

- **Root `mix.exs`**: Manages the umbrella as a whole. It specifies the `apps_path` (usually `"apps"`).
- **`apps/` directory**: Contains the individual applications. Each is a fully functional Mix project.
- **`config/` directory**: Typically, configuration is centralized at the root level, though individual apps can have their own configurations if needed.

## Adding Applications to an Umbrella

To add a new application to an existing umbrella project, you should navigate to the `apps/` directory and run the `mix new` command from there.

### Adding a Plain Elixir App (Logic Only)
If your backend app does not require a database (Ecto), use the standard Elixir generator:
```bash
cd apps
mix new app_name --sup
```
The `--sup` flag is recommended as it scaffolds a supervision tree, allowing the app to manage its own processes (like GenServers) and start automatically as part of the umbrella.

### Adding a Phoenix Backend (Ecto) App

To add a bare Ecto project without web integration (useful for core domain logic):
```bash
cd apps
mix phx.new.ecto app_name
```

### Adding a Phoenix API/Backend App (No Ecto)
If you need a Phoenix application (e.g., for routing or API endpoints) but don't want Ecto or any frontend assets:
```bash
cd apps
mix phx.new app_name --no-ecto --no-html --no-assets
```
This is useful for creating lean microservices or API-only gateways within your umbrella that don't directly interact with a database.

### Adding a Phoenix HTML/JSON App (Full Stack)
To add a full Phoenix application (with its own Ecto schemas if desired, though usually these reside in a core app):
```bash
cd apps
mix phx.new.app app_name
```

## Key Concepts

### Shared Dependencies and Build
One of the main advantages of umbrella projects is that all applications share the same `deps/` and `_build/` directories at the root level. This ensures:
- Dependencies are only downloaded and compiled once.
- Consistent versions across all apps.
- Faster compilation times.

### Internal Dependencies (`in_umbrella`)
Applications within the umbrella can depend on each other. This is declared in the `deps/0` function of an app's `mix.exs` using the `in_umbrella: true` option:

```elixir
defp deps do
  [
    {:my_other_app, in_umbrella: true}
  ]
end
```

### Centralized Configuration
By default, Mix projects in an umbrella are configured to load the configuration from the root's `config/config.exs`. This allows you to manage settings for all applications in one place.

## Phoenix Umbrella Projects

Phoenix uses umbrella projects to encourage separation of concerns, typically splitting a project into:
1. **Domain App**: Contains the business logic, database schemas (Ecto), and core functionality.
2. **Web App**: Contains the Phoenix controllers, views, templates, and LiveViews.

### Generating a Phoenix Umbrella
To create a Phoenix umbrella project, use:
```bash
mix phx.new my_app --umbrella
```

This generates:
- `apps/my_app`: The core business logic.
- `apps/my_app_web`: The web interface.

### Configuration in Phoenix Umbrella
In the web application's configuration, you'll often see a `:context_app` setting. This tells Phoenix where to look for the domain logic when running generators:

```elixir
config :my_app_web,
  ecto_repos: [MyApp.Repo],
  generators: [context_app: :my_app]
```

## Benefits and Trade-offs

### Benefits
- **Clear Boundaries**: Forces you to think about how different parts of your system interact.
- **Efficient Development**: Shared dependencies and build artifacts simplify local development.
- **Flexible Deployment**: You can choose to deploy the whole umbrella or just specific applications (though this requires careful dependency management).

### Trade-offs
- **Complexity**: Managing multiple `mix.exs` files can be more complex than a single-app project.
- **Tight Coupling**: If apps depend heavily on each other via `in_umbrella: true`, they may become difficult to separate later.

## Official Documentation References
- [Mix Umbrella Projects Guide](https://hexdocs.pm/elixir/introduction-to-mix.html#umbrella-projects)
- [Phoenix Umbrella Guide](https://hexdocs.pm/phoenix/umbrella_projects.html)

defmodule Perme8.Events.DomainEvent do
  @moduledoc """
  Macro for defining typed domain event structs.

  Provides a consistent structure for all domain events with auto-generated
  metadata (event_id, occurred_at) and derived event_type from module name.

  ## Usage

      defmodule MyApp.Context.Domain.Events.SomethingHappened do
        use Perme8.Events.DomainEvent,
          aggregate_type: "entity",
          fields: [entity_id: nil, name: nil],
          required: [:entity_id]
      end

  ## Base Fields

  Every event struct includes these base fields:
  - `event_id` - Auto-generated UUID v4
  - `event_type` - Derived from module name (e.g., "context.something_happened")
  - `aggregate_type` - From `:aggregate_type` option
  - `aggregate_id` - Required, identifies the aggregate
  - `actor_id` - Required, identifies who caused the event
  - `workspace_id` - Optional, nil for global events
  - `occurred_at` - Auto-generated UTC datetime
  - `metadata` - Defaults to empty map

  ## Location

  This module lives in the `identity` app because it must be available at
  compile-time for all umbrella apps (including `agents` which cannot depend
  on `jarga` due to a cyclic dependency). The rest of the event infrastructure
  (EventBus, EventHandler, LegacyBridge) remains in `jarga`.

  ## Boundary

  Defined as a standalone boundary with `check: [in: false]` so any module in
  any app can reference it without needing to declare it as a dependency. This is
  necessary because it lives in the `identity` app but is used by domain layers
  across all apps (jarga, agents, ERM).
  """

  use Boundary,
    top_level?: true,
    check: [in: false, out: true],
    deps: [],
    exports: []

  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])
    required = Keyword.get(opts, :required, [])
    aggregate_type = Keyword.get(opts, :aggregate_type, "unknown")

    base_required = [:aggregate_id, :actor_id]
    all_required = base_required ++ required

    base_fields =
      Macro.escape(
        event_id: nil,
        event_type: nil,
        aggregate_type: nil,
        aggregate_id: nil,
        actor_id: nil,
        workspace_id: nil,
        occurred_at: nil,
        metadata: %{}
      )

    domain_event_module = __MODULE__

    quote do
      @enforce_keys unquote(all_required)
      defstruct unquote(base_fields) ++ unquote(fields)

      @doc "Returns the event type string derived from the module name."
      def event_type do
        unquote(domain_event_module).derive_event_type(__MODULE__)
      end

      @doc "Returns the aggregate type string."
      def aggregate_type do
        unquote(aggregate_type)
      end

      @doc "Creates a new event with auto-generated event_id and occurred_at."
      def new(attrs) when is_map(attrs) do
        attrs =
          attrs
          |> Map.put(:event_id, Ecto.UUID.generate())
          |> Map.put(:occurred_at, DateTime.utc_now())
          |> Map.put(:event_type, event_type())
          |> Map.put(:aggregate_type, unquote(aggregate_type))
          |> Map.put_new(:metadata, %{})

        struct!(__MODULE__, attrs)
      end
    end
  end

  @doc """
  Derives the event type string from a module name.

  Algorithm:
  1. Split module name by "."
  2. Find context segment (before "Domain" or 2nd segment for non-Domain events)
  3. Take last segment as event name
  4. Convert both to snake_case
  5. Return "context.event_name"

  ## Examples

      iex> Perme8.Events.DomainEvent.derive_event_type(Jarga.Projects.Domain.Events.ProjectCreated)
      "projects.project_created"

      iex> Perme8.Events.DomainEvent.derive_event_type(Agents.Domain.Events.AgentUpdated)
      "agents.agent_updated"
  """
  def derive_event_type(module) do
    parts = module |> Module.split()
    event_name = parts |> List.last() |> Macro.underscore()

    context =
      case Enum.find_index(parts, &(&1 == "Domain")) do
        nil ->
          # No "Domain" segment — use 2nd-to-last segment as context
          parts |> Enum.at(-2) |> Macro.underscore()

        0 ->
          # "Domain" is the first segment — use 2nd segment
          parts |> Enum.at(1) |> Macro.underscore()

        idx ->
          # Context is the segment before "Domain"
          # But if the context segment is preceded by an app name (e.g., "Jarga"),
          # we want just the context. Find the segment right before "Domain".
          parts |> Enum.at(idx - 1) |> Macro.underscore()
      end

    "#{context}.#{event_name}"
  end
end

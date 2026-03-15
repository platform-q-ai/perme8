defmodule Chat.Application.UseCases.CreateSession do
  @moduledoc """
  Creates a new chat session.

  Validates that cross-app references (user_id, workspace_id) exist via
  Identity's public API before creating the session. Returns error tuples
  for invalid references rather than creating orphaned records.
  """

  alias Chat.Domain.Events.ChatSessionStarted
  alias Chat.Domain.Policies.ReferenceValidationPolicy

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus
  @default_identity_api Chat.Infrastructure.Adapters.IdentityApiAdapter

  @max_auto_title_length 50

  def execute(attrs, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])
    identity_api = Keyword.get(opts, :identity_api, @default_identity_api)

    with :ok <- validate_references(attrs, identity_api) do
      attrs = maybe_generate_title(attrs)

      case session_repository.create_session(attrs) do
        {:ok, session} ->
          emit_session_started_event(session, event_bus, event_bus_opts)
          {:ok, session}

        error ->
          error
      end
    end
  end

  defp validate_references(attrs, identity_api) do
    user_result = safe_user_exists?(identity_api, attrs.user_id)
    workspace_result = safe_validate_workspace(identity_api, attrs, user_result)

    ReferenceValidationPolicy.validate_references(user_result, workspace_result)
  end

  defp safe_user_exists?(identity_api, user_id) do
    identity_api.user_exists?(user_id)
  rescue
    _ -> {:error, :identity_unavailable}
  end

  defp safe_validate_workspace(identity_api, attrs, user_result) do
    workspace_id = Map.get(attrs, :workspace_id)

    cond do
      is_nil(workspace_id) ->
        nil

      user_result !== true ->
        # Skip workspace validation if user validation already failed;
        # the user error will be returned first by the policy anyway
        nil

      true ->
        identity_api.validate_workspace_access(attrs.user_id, workspace_id)
    end
  rescue
    _ -> {:error, :identity_unavailable}
  end

  defp emit_session_started_event(session, event_bus, event_bus_opts) do
    event =
      ChatSessionStarted.new(%{
        aggregate_id: session.id,
        actor_id: session.user_id,
        session_id: session.id,
        user_id: session.user_id,
        workspace_id: session.workspace_id
      })

    event_bus.emit(event, event_bus_opts)
  end

  defp maybe_generate_title(%{title: title} = attrs) when not is_nil(title), do: attrs

  defp maybe_generate_title(%{first_message: message} = attrs)
       when is_binary(message) and message != "" do
    Map.put(attrs, :title, generate_title_from_message(message))
  end

  defp maybe_generate_title(attrs), do: attrs

  defp generate_title_from_message(message) do
    title = message |> String.trim() |> String.split("\n") |> List.first()

    if String.length(title) > @max_auto_title_length do
      String.slice(title, 0, @max_auto_title_length - 3) <> "..."
    else
      title
    end
  end
end

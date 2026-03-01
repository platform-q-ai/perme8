defmodule Chat.Application.UseCases.CreateSession do
  @moduledoc """
  Creates a new chat session.
  """

  alias Chat.Domain.Events.ChatSessionStarted

  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  @max_auto_title_length 50

  def execute(attrs, opts \\ []) do
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    attrs = maybe_generate_title(attrs)

    case session_repository.create_session(attrs) do
      {:ok, session} ->
        emit_session_started_event(session, event_bus, event_bus_opts)
        {:ok, session}

      error ->
        error
    end
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

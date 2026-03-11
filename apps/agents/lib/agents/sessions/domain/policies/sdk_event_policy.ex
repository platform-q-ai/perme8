defmodule Agents.Sessions.Domain.Policies.SdkEventPolicy do
  @moduledoc """
  Pure policy mapping raw SDK events to Session updates and domain events.

  No I/O is performed here. The policy receives a Session and an SDK event map,
  then returns either `{:ok, updated_session, events}` or `{:skip, reason}`.
  """

  alias Agents.Sessions.Domain.Entities.Session
  alias Agents.Sessions.Domain.Policies.{SdkErrorPolicy, SdkEventTypes, SessionLifecyclePolicy}

  alias Agents.Sessions.Domain.Events.{
    SessionCompacted,
    SessionDiffProduced,
    SessionErrorOccurred,
    SessionFileEdited,
    SessionMessageUpdated,
    SessionMetadataUpdated,
    SessionPermissionRequested,
    SessionPermissionResolved,
    SessionRetrying,
    SessionServerConnected,
    SessionStateChanged
  }

  @type result :: {:ok, Session.t(), [struct()]} | {:skip, atom()}

  @terminal_safe_events [
    "server.connected",
    "session.created",
    "session.updated",
    "session.compacted",
    "session.diff"
  ]

  @doc "Applies a raw SDK event to a session."
  @spec apply_event(Session.t(), map()) :: result()
  def apply_event(session, %{"type" => type} = event) when is_binary(type) do
    cond do
      not SdkEventTypes.handled?(type) ->
        {:skip, :not_relevant}

      SessionLifecyclePolicy.terminal?(session.lifecycle_state) and
          type not in @terminal_safe_events ->
        {:skip, :already_terminal}

      true ->
        handle_event(session, type, Map.get(event, "properties", %{}))
    end
  end

  def apply_event(_session, _event), do: {:skip, :not_relevant}

  defp handle_event(session, "session.status", %{"status" => "busy"}), do: {:ok, session, []}

  defp handle_event(session, "session.status", %{"status" => "idle"}),
    do: complete_if_possible(session)

  defp handle_event(session, "session.status", %{"status" => "retry"} = props) do
    attempt = Map.get(props, "attempt", 0)
    message = Map.get(props, "message")
    next_at = Map.get(props, "next")

    updated =
      Session.update(session, %{
        retry_attempt: attempt,
        retry_message: message,
        retry_next_at: next_at
      })

    events =
      [
        SessionRetrying.new(
          base_event_attrs(session)
          |> Map.merge(%{attempt: attempt, message: message, next_at: next_at})
        )
      ]

    {:ok, updated, events}
  end

  defp handle_event(session, "session.status", _props), do: {:ok, session, []}

  defp handle_event(session, "session.idle", _props), do: complete_if_possible(session)

  defp handle_event(session, "session.error", props) do
    category = Map.get(props, "category")
    message = Map.get(props, "message", "Unknown error")
    {severity, category_atom} = SdkErrorPolicy.classify(category)

    error_event =
      SessionErrorOccurred.new(
        base_event_attrs(session)
        |> Map.merge(%{
          error_message: message,
          error_category: category_atom,
          recoverable: severity == :recoverable
        })
      )

    case severity do
      :recoverable ->
        updated =
          Session.update(session, %{
            error: message,
            error_category: category_atom,
            error_recoverable: true
          })

        {:ok, updated, [error_event]}

      :terminal ->
        transition_with_state_event(
          session,
          :failed,
          %{error: message, error_category: category_atom, error_recoverable: false},
          [error_event]
        )
    end
  end

  defp handle_event(session, "permission.updated", props) do
    if session.lifecycle_state != :running do
      {:skip, :invalid_state}
    else
      permission_id = Map.get(props, "id")
      tool_name = Map.get(props, "tool")
      action = Map.get(props, "action")

      permission_event =
        SessionPermissionRequested.new(
          base_event_attrs(session)
          |> Map.merge(%{
            permission_id: permission_id,
            tool_name: tool_name,
            action_description: action
          })
        )

      attrs = %{permission_context: %{tool: tool_name, action: action, id: permission_id}}

      transition_with_state_event(session, :awaiting_feedback, attrs, [permission_event])
    end
  end

  defp handle_event(session, "permission.replied", props) do
    if session.lifecycle_state != :awaiting_feedback do
      {:skip, :invalid_state}
    else
      permission_id = Map.get(props, "id")
      outcome = Map.get(props, "outcome", "allowed")
      new_state = if outcome == "denied", do: :cancelled, else: :running

      resolved_event =
        SessionPermissionResolved.new(
          base_event_attrs(session)
          |> Map.merge(%{permission_id: permission_id, outcome: outcome})
        )

      transition_with_state_event(session, new_state, %{permission_context: nil}, [resolved_event])
    end
  end

  defp handle_event(session, "message.updated", _props) do
    updated = Session.track_message(session)
    {:ok, updated, [build_message_updated(updated)]}
  end

  defp handle_event(session, "message.removed", _props) do
    updated = Session.remove_message(session)
    {:ok, updated, [build_message_updated(updated)]}
  end

  defp handle_event(session, "message.part.updated", %{"type" => "text", "delta" => _delta}) do
    {:ok, Session.start_streaming(session), []}
  end

  defp handle_event(session, "message.part.updated", %{"type" => "tool-start"}) do
    updated = Session.increment_tool_calls(session)
    {:ok, updated, [build_message_updated(updated)]}
  end

  defp handle_event(session, "message.part.updated", %{"type" => "tool", "state" => "completed"}) do
    updated = Session.decrement_tool_calls(session)
    {:ok, updated, [build_message_updated(updated)]}
  end

  defp handle_event(session, "message.part.updated", _props), do: {:ok, session, []}

  defp handle_event(session, "message.part.removed", _props), do: {:ok, session, []}

  defp handle_event(session, "session.created", props) do
    updated = Session.update(session, %{sdk_session_title: Map.get(props, "title")})
    {:ok, updated, []}
  end

  defp handle_event(session, "session.updated", props) do
    title = Map.get(props, "title")
    share_status = Map.get(props, "share")

    updated = Session.update(session, %{sdk_session_title: title, sdk_share_status: share_status})

    events =
      [
        SessionMetadataUpdated.new(
          base_event_attrs(session)
          |> Map.merge(%{title: title, share_status: share_status})
        )
      ]

    {:ok, updated, events}
  end

  defp handle_event(session, "session.deleted", _props),
    do: transition_with_state_event(session, :cancelled, %{}, [])

  defp handle_event(session, "session.compacted", _props) do
    updated = Session.mark_compacted(session)
    {:ok, updated, [SessionCompacted.new(base_event_attrs(session))]}
  end

  defp handle_event(session, "session.diff", props) do
    event =
      SessionDiffProduced.new(
        base_event_attrs(session)
        |> Map.put(:diff_summary, Map.get(props, "summary"))
      )

    {:ok, session, [event]}
  end

  defp handle_event(session, "server.connected", _props) do
    {:ok, session, [SessionServerConnected.new(base_event_attrs(session))]}
  end

  defp handle_event(session, "server.instance.disposed", _props) do
    error_message = "Server instance terminated unexpectedly"

    error_event =
      SessionErrorOccurred.new(
        base_event_attrs(session)
        |> Map.merge(%{
          error_message: error_message,
          error_category: :server_disposed,
          recoverable: false
        })
      )

    transition_with_state_event(session, :failed, %{error: error_message}, [error_event])
  end

  defp handle_event(session, "file.edited", props) do
    path = Map.get(props, "path", "unknown")
    updated = Session.record_file_edit(session, path)

    event =
      SessionFileEdited.new(
        base_event_attrs(session)
        |> Map.merge(%{file_path: path, edit_summary: Map.get(props, "summary")})
      )

    {:ok, updated, [event]}
  end

  defp complete_if_possible(session) do
    if session.lifecycle_state in [:running, :awaiting_feedback] do
      transition_with_state_event(session, :completed, %{streaming_active: false}, [])
    else
      {:skip, :no_transition}
    end
  end

  defp transition_with_state_event(session, to_state, attrs, events) do
    if SessionLifecyclePolicy.can_transition?(session.lifecycle_state, to_state) do
      updated = Session.update(session, Map.put(attrs, :lifecycle_state, to_state))
      {:ok, updated, events ++ [build_state_changed(session, to_state)]}
    else
      {:skip, :no_transition}
    end
  end

  defp build_state_changed(session, to_state) do
    SessionStateChanged.new(
      base_event_attrs(session)
      |> Map.merge(%{
        from_state: session.lifecycle_state,
        to_state: to_state,
        lifecycle_state: to_state,
        container_id: session.container_id
      })
    )
  end

  defp build_message_updated(session) do
    SessionMessageUpdated.new(
      base_event_attrs(session)
      |> Map.merge(%{
        message_count: session.message_count,
        streaming_active: session.streaming_active,
        active_tool_calls: session.active_tool_calls
      })
    )
  end

  defp base_event_attrs(session) do
    %{
      aggregate_id: session.task_id,
      actor_id: session.user_id,
      task_id: session.task_id,
      user_id: session.user_id
    }
  end
end

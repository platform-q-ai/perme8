defmodule Agents.Sessions.Application.UseCases.CreateInteraction do
  @moduledoc """
  Use case for creating a session interaction record.

  Validates the interaction type and direction, creates the record,
  and for answer types, marks the corresponding question as delivered.
  """

  alias Agents.Sessions.Domain.Entities.Interaction
  alias Agents.Sessions.Domain.Policies.InteractionPolicy

  @default_interaction_repo Agents.Sessions.Infrastructure.Repositories.InteractionRepository

  @spec execute(map(), keyword()) :: {:ok, Interaction.t()} | {:error, term()}
  def execute(attrs, opts \\ []) do
    interaction_repo = Keyword.get(opts, :interaction_repo, @default_interaction_repo)

    type = to_atom(attrs[:type] || attrs["type"])
    direction = to_atom(attrs[:direction] || attrs["direction"])

    with :ok <- validate_type(type),
         :ok <- validate_direction(direction) do
      string_attrs = %{
        session_id: attrs[:session_id],
        task_id: attrs[:task_id],
        type: to_string(type),
        direction: to_string(direction),
        payload: attrs[:payload] || %{},
        correlation_id: attrs[:correlation_id],
        status: "pending"
      }

      case interaction_repo.create_interaction(string_attrs) do
        {:ok, schema} ->
          # For answers, mark the corresponding question as delivered
          if type == :answer && attrs[:correlation_id] do
            mark_question_delivered(attrs[:session_id], attrs[:correlation_id], interaction_repo)
          end

          {:ok, Interaction.from_schema(schema)}

        error ->
          error
      end
    end
  end

  defp validate_type(type) do
    if InteractionPolicy.valid_type?(type), do: :ok, else: {:error, :invalid_type}
  end

  defp validate_direction(direction) do
    if InteractionPolicy.valid_direction?(direction), do: :ok, else: {:error, :invalid_direction}
  end

  defp mark_question_delivered(session_id, correlation_id, interaction_repo) do
    case interaction_repo.get_pending_question_by_correlation_id(session_id, correlation_id) do
      %{type: "question", status: "pending"} = question ->
        interaction_repo.update_status(question, %{status: "delivered"})

      _ ->
        :ok
    end
  end

  defp to_atom(val) when is_atom(val), do: val

  defp to_atom(val) when is_binary(val) do
    String.to_existing_atom(val)
  rescue
    ArgumentError -> nil
  end

  defp to_atom(_), do: nil
end

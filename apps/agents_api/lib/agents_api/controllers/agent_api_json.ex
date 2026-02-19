defmodule AgentsApi.AgentApiJSON do
  @moduledoc """
  JSON rendering for Agent API endpoints.
  """

  @doc """
  Renders a list of agents.
  """
  def index(%{agents: agents}) do
    %{data: Enum.map(agents, &agent_data/1)}
  end

  @doc """
  Renders a single agent.
  """
  def show(%{agent: agent}) do
    %{data: agent_data(agent)}
  end

  @doc """
  Renders a created agent.
  """
  def created(%{agent: agent}) do
    %{data: agent_data(agent)}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  @doc """
  Renders validation errors from a changeset.
  """
  def validation_error(%{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  defp agent_data(agent) do
    %{
      id: agent.id,
      name: agent.name,
      description: agent.description,
      system_prompt: agent.system_prompt,
      model: agent.model,
      temperature: agent.temperature,
      visibility: agent.visibility,
      enabled: agent.enabled,
      inserted_at: agent.inserted_at,
      updated_at: agent.updated_at
    }
  end
end

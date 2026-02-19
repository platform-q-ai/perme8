defmodule AgentsApi.AgentQueryController do
  @moduledoc """
  Controller for Agent Query execution via REST API.

  Provides a synchronous endpoint that executes a query against an agent
  and returns the complete response. The agent's model, temperature, and
  system prompt settings are used for the query.

  ## Endpoints

    * `POST /api/agents/:id/query` - Execute a query against an agent

  """

  use AgentsApi, :controller

  @query_timeout_ms 60_000

  @doc """
  Executes a query against an agent.

  ## Request Body

    * `question` - Required. The question to ask the agent.
    * `context` - Optional. Additional context map.

  ## Responses

    * 200 - Query executed successfully
    * 404 - Agent not found or not owned by user
    * 422 - Missing required `question` parameter
    * 504 - Query timed out

  """
  def create(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with {:ok, question} <- extract_question(params),
         {:ok, agent} <- Agents.get_user_agent(id, user.id) do
      execute_query(conn, agent, question, params)
    else
      {:error, :missing_question} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, message: "question is required")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Agent not found")
    end
  end

  defp extract_question(%{"question" => question}) when is_binary(question) and question != "" do
    {:ok, question}
  end

  defp extract_question(_), do: {:error, :missing_question}

  defp execute_query(conn, agent, question, _params) do
    query_params = %{
      question: question,
      assigns: %{},
      agent: agent
    }

    case Agents.agent_query(query_params, self()) do
      {:ok, _pid} ->
        collect_response(conn)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, message: "Query failed: #{inspect(reason)}")
    end
  end

  defp collect_response(conn) do
    collect_chunks(conn, [])
  end

  defp collect_chunks(conn, chunks) do
    receive do
      {:chunk, chunk} ->
        collect_chunks(conn, [chunk | chunks])

      {:done, full_response} ->
        render(conn, :show, response: full_response)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, message: "Query error: #{inspect(reason)}")
    after
      @query_timeout_ms ->
        response =
          if chunks == [] do
            conn
            |> put_status(:gateway_timeout)
            |> render(:error, message: "Query timed out")
          else
            # Return partial response if we have some chunks
            partial = chunks |> Enum.reverse() |> Enum.join("")
            render(conn, :show, response: partial)
          end

        response
    end
  end
end

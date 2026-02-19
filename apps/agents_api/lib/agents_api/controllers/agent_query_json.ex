defmodule AgentsApi.AgentQueryJSON do
  @moduledoc """
  JSON rendering for Agent Query API endpoints.
  """

  @doc """
  Renders a query response.
  """
  def show(%{response: response}) do
    %{data: %{response: response}}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end
end

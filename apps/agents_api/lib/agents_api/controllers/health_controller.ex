defmodule AgentsApi.HealthController do
  @moduledoc """
  Health check endpoint for the Agents API.
  """

  use AgentsApi, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end

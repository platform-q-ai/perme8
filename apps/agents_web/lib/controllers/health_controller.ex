defmodule AgentsWeb.HealthController do
  @moduledoc """
  Minimal health check endpoint for readiness probes (exo-bdd, load balancers).
  """

  use AgentsWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end

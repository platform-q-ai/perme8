defmodule EntityRelationshipManager.HealthController do
  use EntityRelationshipManager, :controller

  def show(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end
end

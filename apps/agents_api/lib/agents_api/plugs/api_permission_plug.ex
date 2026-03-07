defmodule AgentsApi.Plugs.ApiPermissionPlug do
  @moduledoc "Enforces API key permission scopes on REST endpoints."

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: Keyword.fetch!(opts, :scope)

  @impl Plug
  def call(conn, required_scope) do
    api_key = conn.assigns[:api_key]

    if Identity.api_key_has_permission?(api_key, required_scope) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        403,
        Jason.encode!(%{error: "insufficient_permissions", required: required_scope})
      )
      |> halt()
    end
  end
end

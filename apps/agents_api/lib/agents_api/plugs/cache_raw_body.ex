defmodule AgentsApi.Plugs.CacheRawBody do
  @moduledoc """
  Caches the request body in `conn.private[:raw_body]` for signature validation.
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = update_in(conn.private[:raw_body], &((&1 || "") <> body))
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = update_in(conn.private[:raw_body], &((&1 || "") <> body))
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

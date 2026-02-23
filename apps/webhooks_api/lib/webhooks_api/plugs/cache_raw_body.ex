defmodule WebhooksApi.Plugs.CacheRawBody do
  @moduledoc """
  Custom body reader that caches the raw request body in `conn.private[:raw_body]`.

  Used with `Plug.Parsers` `:body_reader` option to preserve the original
  raw bytes for HMAC signature verification on inbound webhook routes.
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

defmodule JargaApi.Plugs.RawBodyReader do
  @moduledoc """
  Custom body reader that caches the raw request body in `conn.private[:raw_body]`.

  This is used by inbound webhook endpoints where the raw body is needed
  for HMAC signature verification. The JSON parser will still parse the body
  normally, but the raw bytes are preserved for signature checks.

  ## Usage

  Configure as the body reader in `Plug.Parsers`:

      plug Plug.Parsers,
        parsers: [:json],
        body_reader: {JargaApi.Plugs.RawBodyReader, :read_body, []},
        json_decoder: Phoenix.json_library()
  """

  @doc """
  Reads the request body and stores the raw bytes in conn private.

  Returns `{:ok, body, conn}` with the raw body cached in `conn.private[:raw_body]`.
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

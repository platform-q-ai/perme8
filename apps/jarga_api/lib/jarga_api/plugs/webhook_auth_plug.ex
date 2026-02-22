defmodule JargaApi.Plugs.WebhookAuthPlug do
  @moduledoc """
  Plug for authenticating inbound webhook requests using HMAC signature.

  Extracts the `X-Webhook-Signature` header and assigns it to the connection
  for downstream signature verification by the use case.

  ## Usage

  Add to your router pipeline for inbound webhook endpoints:

      pipeline :webhook_authenticated do
        plug JargaApi.Plugs.WebhookAuthPlug
      end

  ## Header Format

      X-Webhook-Signature: sha256=<hex_digest>

  ## Behavior

  - If header is present and non-empty: assigns `:webhook_signature` and passes through
  - If header is missing or empty: halts with 401 Unauthorized
  """

  import Plug.Conn

  @behaviour Plug

  @error_message "Missing webhook signature"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "x-webhook-signature") do
      [signature] when byte_size(signature) > 0 ->
        assign(conn, :webhook_signature, signature)

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: @error_message}))
        |> halt()
    end
  end
end

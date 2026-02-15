defmodule IdentityWeb.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Plug that adds standard security headers to all responses.

  Applied at the endpoint level (before routing) so that every response —
  including static files, redirects, and error pages — carries these headers.

  Headers set:
    - `x-content-type-options: nosniff` — prevents MIME-type sniffing
    - `x-frame-options: DENY` — prevents clickjacking via iframes
    - `referrer-policy: strict-origin-when-cross-origin` — controls Referer header leakage
    - `content-security-policy` — restricts content sources (allows LiveView inline scripts)
    - `strict-transport-security: max-age=31536000; includeSubDomains` — enforces HTTPS
    - `permissions-policy: camera=(), microphone=(), geolocation=()` — restricts browser features
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:"
    )
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end

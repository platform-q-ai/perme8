defmodule AgentsApi.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Plug that adds standard security headers to all API responses.

  Headers set:
    - `x-content-type-options: nosniff` — prevents MIME-type sniffing
    - `x-frame-options: DENY` — prevents clickjacking via iframes
    - `referrer-policy: strict-origin-when-cross-origin` — controls Referer header leakage
    - `content-security-policy: default-src 'none'` — restrictive CSP for JSON APIs
    - `strict-transport-security: max-age=31536000; includeSubDomains` — enforces HTTPS
    - `permissions-policy: camera=(), microphone=(), geolocation=()` — restricts browser features
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("content-security-policy", "default-src 'none'")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end

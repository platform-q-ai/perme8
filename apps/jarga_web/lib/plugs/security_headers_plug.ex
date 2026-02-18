defmodule JargaWeb.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Plug that adds standard security headers to all responses.

  Applied at the endpoint level (before routing) so that every response —
  including static files, redirects, and error pages — carries these headers.

  Headers set:
    - `x-content-type-options: nosniff` — prevents MIME-type sniffing
    - `x-frame-options: DENY` — prevents clickjacking via iframes
    - `referrer-policy: strict-origin-when-cross-origin` — controls Referer header leakage
    - `content-security-policy` — comprehensive CSP for Phoenix LiveView
    - `strict-transport-security: max-age=31536000; includeSubDomains` — enforces HTTPS
    - `permissions-policy: camera=(), microphone=(), geolocation=()` — restricts browser features

  ## CSP Notes

  Phoenix LiveView requires `'unsafe-inline'` for script-src because it injects
  inline scripts for its runtime. All directives without a `default-src` fallback
  (frame-ancestors, form-action, base-uri) are explicitly set to prevent ZAP
  "Failure to Define Directive with No Fallback" alerts.

  Follows the same pattern as `IdentityWeb.Plugs.SecurityHeadersPlug`.
  """

  import Plug.Conn

  @csp [
         "default-src 'self'",
         "script-src 'self' 'unsafe-inline'",
         "style-src 'self' 'unsafe-inline'",
         "img-src 'self' data:",
         "font-src 'self'",
         "connect-src 'self'",
         "frame-ancestors 'none'",
         "form-action 'self'",
         "base-uri 'self'",
         "object-src 'none'",
         "media-src 'none'"
       ]
       |> Enum.join("; ")

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("content-security-policy", @csp)
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end

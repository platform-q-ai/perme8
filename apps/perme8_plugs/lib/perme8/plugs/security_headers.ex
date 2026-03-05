defmodule Perme8.Plugs.SecurityHeaders do
  @moduledoc """
  Plug that adds standard security headers to all responses.

  Accepts a `:profile` option to select the appropriate Content-Security-Policy:

    - `:liveview` -- permissive CSP with `'unsafe-inline'` for script-src and
      style-src, required by Phoenix LiveView. Use in endpoint-level plugs for
      browser-facing apps.

    - `:api` -- restrictive `default-src 'none'` CSP for JSON-only APIs.
      Use in router pipeline plugs for API apps.

  ## Usage

      # In a LiveView endpoint:
      plug Perme8.Plugs.SecurityHeaders, profile: :liveview

      # In an API router pipeline:
      plug Perme8.Plugs.SecurityHeaders, profile: :api

  ## Headers Set

    - `x-content-type-options: nosniff` -- prevents MIME-type sniffing
    - `x-frame-options: DENY` -- prevents clickjacking via iframes
    - `referrer-policy: strict-origin-when-cross-origin` -- controls Referer header leakage
    - `content-security-policy` -- profile-specific CSP (see above)
    - `strict-transport-security: max-age=31536000; includeSubDomains` -- enforces HTTPS
    - `permissions-policy: camera=(), microphone=(), geolocation=()` -- restricts browser features

  ## CSP Notes

  Phoenix LiveView requires `'unsafe-inline'` for script-src because it injects
  inline scripts for its runtime. LiveView 0.20+ supports nonce-based CSP, which
  would allow removing `'unsafe-inline'` in a future upgrade.
  """

  @behaviour Plug

  import Plug.Conn

  @liveview_csp [
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

  @api_csp "default-src 'none'"

  @valid_profiles [:liveview, :api]

  @impl Plug
  def init(opts) do
    profile = Keyword.get(opts, :profile)

    unless profile do
      raise ArgumentError,
            "missing required :profile option for #{inspect(__MODULE__)}. " <>
              "Expected one of #{inspect(@valid_profiles)}"
    end

    unless profile in @valid_profiles do
      raise ArgumentError,
            "invalid profile #{inspect(profile)} for #{inspect(__MODULE__)}. " <>
              "Expected one of #{inspect(@valid_profiles)}"
    end

    csp =
      case profile do
        :liveview -> @liveview_csp
        :api -> @api_csp
      end

    %{csp: csp}
  end

  @impl Plug
  def call(conn, %{csp: csp}) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("content-security-policy", csp)
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end

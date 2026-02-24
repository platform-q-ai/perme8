defmodule IdentityWeb.Session do
  @moduledoc """
  Provides runtime-resolved session configuration.

  The signing salt is stored in a separate config key (`:session_signing_salt`)
  to avoid compile_env vs runtime value mismatches in releases. The base session
  options (store, key, same_site) are safe to read at compile time because they
  never change between environments.

  ## How it works

  `config.exs` sets `signing_salt: {IdentityWeb.Session, :signing_salt, []}`
  inside `:session_options`. Plug.Session.Cookie resolves MFA tuples at runtime
  when deriving the signing key, so the actual salt is fetched from
  `Application.get_env(:identity, :session_signing_salt)` only when a cookie
  is signed or verified — never at compile time.
  """

  @doc """
  Returns the session signing salt from application config.

  Called at runtime by `Plug.Session.Cookie` via the MFA tuple stored in
  `:session_options`.
  """
  @spec signing_salt() :: String.t()
  def signing_salt do
    Application.get_env(:identity, :session_signing_salt) ||
      raise "missing config :identity, :session_signing_salt"
  end
end

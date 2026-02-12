defmodule Jarga.Accounts do
  @moduledoc """
  Facade for account management operations.

  This module delegates core identity operations to the `Identity` app.

  ## Core Identity Operations (delegated to Identity)

  - User authentication and registration
  - Session management
  - Password and email updates
  - API key management

  ## Migration Note

  This facade delegates to Identity for all core account operations.
  Direct usage of `Identity` module is preferred for new code.

  API-specific use cases (workspace API access, project creation via API)
  have been extracted to the `jarga_api` app under `JargaApi.Accounts`.
  """

  # Boundary configuration - pure delegation facade to Identity
  use Boundary,
    top_level?: true,
    deps: [
      Identity
    ],
    exports: []

  # =============================================================================
  # DELEGATED TO IDENTITY - Core account operations
  # =============================================================================

  ## Database getters

  defdelegate get_user_by_email(email), to: Identity
  defdelegate get_user_by_email_case_insensitive(email), to: Identity
  defdelegate get_user_by_email_and_password(email, password), to: Identity
  defdelegate get_user(id), to: Identity
  defdelegate get_user!(id), to: Identity

  ## User registration

  defdelegate register_user(attrs), to: Identity

  ## Settings

  def sudo_mode?(user, opts \\ []), do: Identity.sudo_mode?(user, opts)

  def change_user_registration(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_registration(user, attrs, opts)

  def change_user_email(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_email(user, attrs, opts)

  defdelegate update_user_email(user, token), to: Identity

  def change_user_password(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_password(user, attrs, opts)

  defdelegate update_user_password(user, attrs), to: Identity

  ## Session

  defdelegate generate_user_session_token(user), to: Identity
  defdelegate get_user_by_session_token(token), to: Identity
  defdelegate get_user_by_magic_link_token(token), to: Identity
  defdelegate login_user_by_magic_link(token), to: Identity
  defdelegate deliver_user_update_email_instructions(user, current_email, url_fun), to: Identity
  defdelegate deliver_login_instructions(user, url_fun), to: Identity
  defdelegate delete_user_session_token(token), to: Identity
  defdelegate get_user_token_by_user_id(user_id), to: Identity

  ## User preferences

  defdelegate get_selected_agent_id(user_id, workspace_id), to: Identity
  defdelegate set_selected_agent_id(user_id, workspace_id, agent_id), to: Identity

  ## API Keys

  defdelegate create_api_key(user_id, attrs), to: Identity
  def list_api_keys(user_id, opts \\ []), do: Identity.list_api_keys(user_id, opts)
  defdelegate update_api_key(user_id, api_key_id, attrs), to: Identity
  defdelegate revoke_api_key(user_id, api_key_id), to: Identity
  defdelegate verify_api_key(plain_token), to: Identity
end

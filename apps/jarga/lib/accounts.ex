defmodule Jarga.Accounts do
  @moduledoc """
  Public API for account management operations.

  This context module serves as a thin facade over the Accounts bounded context,
  delegating complex operations to use cases in the application layer while
  providing simple data access for reads.

  ## Architecture

  - **Simple reads** → Direct database queries via Repo
  - **Complex operations** → Delegated to use cases in `Application.UseCases`
  - **Business rules** → Encapsulated in domain policies

  ## Key Use Cases

  - `UseCases.RegisterUser` - User registration with password hashing
  - `UseCases.LoginByMagicLink` - Passwordless login via magic link
  - `UseCases.UpdateUserPassword` - Password updates with token expiry
  - `UseCases.UpdateUserEmail` - Email change with verification
  - `UseCases.GenerateSessionToken` - Session token generation
  - `UseCases.DeliverLoginInstructions` - Magic link email delivery
  - `UseCases.DeliverUserUpdateEmailInstructions` - Email change verification

  - `UseCases.CreateApiKey` - API key creation with token generation
  - `UseCases.ListApiKeys` - List user's API keys
  - `UseCases.UpdateApiKey` - Update API key properties
  - `UseCases.RevokeApiKey` - Deactivate API key
  - `UseCases.VerifyApiKey` - Verify API key token

  ## Domain Policies

  - `AuthenticationPolicy` - Authentication business rules (sudo mode)
  - `TokenPolicy` - Token expiration and validity rules
  - `ApiKeyPolicy` - API key ownership and management permissions
  - `WorkspaceAccessPolicy` - Workspace access validation for API keys
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Note: Does NOT depend on Jarga.Workspaces to avoid dependency cycle.
  # Use cases in this context use dependency injection for cross-context calls.
  #
  # This context boundary contains three layer boundaries:
  # - Jarga.Accounts.Domain (deps: [])
  # - Jarga.Accounts.Application (deps: [Domain])
  # - Jarga.Accounts.Infrastructure (deps: [Domain, Application, Repo, Mailer])
  use Boundary,
    top_level?: true,
    deps: [
      # Layer boundaries
      Jarga.Accounts.Domain,
      Jarga.Accounts.Application,
      Jarga.Accounts.Infrastructure,
      # Shared infrastructure (needed for direct Repo access in facade)
      Jarga.Repo
    ],
    exports: [
      # Re-export from Domain layer
      {Domain.Entities.User, []},
      {Domain.Entities.ApiKey, []},
      {Domain.Scope, []},
      {Domain.Services.TokenBuilder, []},
      {Domain.Policies.WorkspaceAccessPolicy, []},
      # Re-export from Application layer
      {Application.Services.PasswordService, []},
      {Application.Services.ApiKeyTokenService, []},
      # Re-export from Infrastructure layer (for external access)
      {Infrastructure.Schemas.UserSchema, []},
      {Infrastructure.Schemas.UserTokenSchema, []},
      {Infrastructure.Schemas.ApiKeySchema, []}
    ]

  import Ecto.Query, warn: false
  alias Jarga.Repo

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Domain.Policies.AuthenticationPolicy
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Accounts.Infrastructure.Schemas.{UserSchema, UserTokenSchema}
  alias Jarga.Accounts.Application.UseCases

  ## Database getters

  @doc """
  Gets a user by email. Returns `nil` if not found.
  """
  def get_user_by_email(email) when is_binary(email) do
    case Repo.get_by(UserSchema, email: email) do
      nil -> nil
      schema -> User.from_schema(schema)
    end
  end

  @doc """
  Gets a user by email (case-insensitive). Returns `nil` if not found.
  """
  def get_user_by_email_case_insensitive(email) when is_binary(email) do
    case email
         |> Queries.by_email_case_insensitive()
         |> Repo.one() do
      nil -> nil
      schema -> User.from_schema(schema)
    end
  end

  @doc """
  Gets a user by email and password.

  Returns the user only if the password is valid AND the email is confirmed.
  Returns `nil` otherwise.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user_schema = Repo.get_by(UserSchema, email: email)

    if user_schema do
      user = User.from_schema(user_schema)

      if User.valid_password?(user, password) and user.confirmed_at != nil do
        user
      else
        nil
      end
    else
      nil
    end
  end

  @doc """
  Gets a single user by ID. Returns `nil` if not found.
  """
  def get_user(id) do
    case Repo.get(UserSchema, id) do
      nil -> nil
      schema -> User.from_schema(schema)
    end
  end

  @doc """
  Gets a single user. Raises `Ecto.NoResultsError` if not found.
  """
  def get_user!(id) do
    UserSchema
    |> Repo.get!(id)
    |> User.from_schema()
  end

  ## User registration

  @doc """
  Registers a user with the given attributes.

  Delegates to `UseCases.RegisterUser` which handles password hashing
  and user creation in a transaction.
  """
  def register_user(attrs) do
    UseCases.RegisterUser.execute(%{attrs: attrs})
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be customized via options.

  ## Options

    - `:minutes` - Time limit in minutes (default: -20, meaning 20 minutes ago)
    - `:current_time` - Current DateTime for comparison (default: DateTime.utc_now())

  Delegates to `AuthenticationPolicy.sudo_mode?/2`.
  """
  def sudo_mode?(user, opts \\ []) do
    AuthenticationPolicy.sudo_mode?(user, opts)
  end

  @doc """
  Returns a changeset for user registration.
  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    UserSchema.registration_changeset(user, attrs, opts)
  end

  @doc """
  Returns a changeset for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    UserSchema.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  Delegates to `UseCases.UpdateUserEmail` which verifies the token,
  updates the email, and deletes the token in a transaction.
  """
  def update_user_email(user, token) do
    UseCases.UpdateUserEmail.execute(%{
      user: user,
      token: token
    })
  end

  @doc """
  Returns a changeset for changing the user password.
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    UserSchema.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Delegates to `UseCases.UpdateUserPassword` which hashes the password,
  updates the user, and expires all existing tokens in a transaction.

  Returns `{:ok, {user, expired_tokens}}` or `{:error, changeset}`.
  """
  def update_user_password(user, attrs) do
    UseCases.UpdateUserPassword.execute(%{user: user, attrs: attrs})
  end

  ## Session

  @doc """
  Generates a session token for the user.

  Delegates to `UseCases.GenerateSessionToken`.
  """
  def generate_user_session_token(user) do
    UseCases.GenerateSessionToken.execute(%{user: user})
  end

  @doc """
  Gets the user by session token.

  Returns `{user, token_inserted_at}` if valid, `nil` otherwise.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = Queries.verify_session_token_query(token)

    case Repo.one(query) do
      {user_schema, token_inserted_at} ->
        {User.from_schema(user_schema), token_inserted_at}

      nil ->
        nil
    end
  end

  @doc """
  Gets the user by magic link token. Returns `nil` if invalid.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- Queries.verify_magic_link_token_query(token),
         {user_schema, _token} <- Repo.one(query) do
      User.from_schema(user_schema)
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link token.

  Delegates to `UseCases.LoginByMagicLink` which handles three cases:
  1. Confirmed user → login and expire token
  2. Unconfirmed user without password → confirm, login, expire all tokens
  3. Unconfirmed user with password → confirm, login, expire token

  Returns `{:ok, {user, expired_tokens}}` or `{:error, reason}`.
  """
  def login_user_by_magic_link(token) do
    UseCases.LoginByMagicLink.execute(%{token: token})
  end

  @doc """
  Delivers email update instructions to the user.

  Delegates to `UseCases.DeliverUserUpdateEmailInstructions` which generates
  a change email token and sends verification email.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    UseCases.DeliverUserUpdateEmailInstructions.execute(%{
      user: user,
      current_email: current_email,
      url_fun: update_email_url_fun
    })
  end

  @doc """
  Delivers magic link login instructions to the user.

  Delegates to `UseCases.DeliverLoginInstructions` which generates
  a login token and sends magic link email.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    UseCases.DeliverLoginInstructions.execute(%{
      user: user,
      url_fun: magic_link_url_fun
    })
  end

  @doc """
  Deletes the session token.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(Queries.tokens_by_token_and_context(token, "session"))
    :ok
  end

  @doc """
  Gets a user token by user_id (primarily for testing).
  Returns a domain UserToken entity.
  """
  def get_user_token_by_user_id(user_id) do
    Repo.get_by!(UserTokenSchema, user_id: user_id)
    |> UserTokenSchema.to_entity()
  end

  ## User preferences

  @doc """
  Gets a user's selected agent for a specific workspace.
  Returns nil if no preference is set.
  """
  def get_selected_agent_id(user_id, workspace_id)
      when is_binary(user_id) and is_binary(workspace_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        nil

      user_schema ->
        user = User.from_schema(user_schema)
        get_in(user.preferences, ["selected_agents", workspace_id])
    end
  end

  @doc """
  Sets a user's selected agent for a specific workspace.
  """
  def set_selected_agent_id(user_id, workspace_id, agent_id)
      when is_binary(user_id) and is_binary(workspace_id) and is_binary(agent_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        {:error, :user_not_found}

      user_schema ->
        user = User.from_schema(user_schema)
        selected_agents = Map.get(user.preferences, "selected_agents", %{})
        updated_selected_agents = Map.put(selected_agents, workspace_id, agent_id)

        updated_preferences =
          Map.put(user.preferences, "selected_agents", updated_selected_agents)

        case user_schema
             |> Ecto.Changeset.change(preferences: updated_preferences)
             |> Repo.update() do
          {:ok, updated_schema} -> {:ok, User.from_schema(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  ## API Keys

  @doc """
  Creates a new API key for the user.

  ## Parameters

    - `user_id` - The user ID to create the API key for
    - `attrs` - Map with API key attributes (name, description, workspace_access)

  ## Returns

    `{:ok, {api_key, plain_token}}` on success - plain token shown only once
    `{:error, :forbidden}` if user doesn't have access to specified workspaces

  """
  def create_api_key(user_id, attrs) when is_binary(user_id) and is_map(attrs) do
    UseCases.CreateApiKey.execute(user_id, attrs)
  end

  @doc """
  Lists API keys for a user.

  ## Parameters

    - `user_id` - The user ID to list API keys for
    - `opts` - Options (is_active: true/false/nil to filter by status)

  ## Returns

    `{:ok, api_keys}` on success

  """
  def list_api_keys(user_id, opts \\ []) when is_binary(user_id) do
    UseCases.ListApiKeys.execute(user_id, opts)
  end

  @doc """
  Updates an existing API key.

  ## Parameters

    - `user_id` - The user ID performing the update
    - `api_key_id` - The API key ID to update
    - `attrs` - Map with fields to update (name, description, workspace_access)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :not_found}` if API key doesn't exist
    `{:error, :forbidden}` if user doesn't own the API key or lacks workspace access

  """
  def update_api_key(user_id, api_key_id, attrs)
      when is_binary(user_id) and is_binary(api_key_id) and is_map(attrs) do
    UseCases.UpdateApiKey.execute(user_id, api_key_id, attrs)
  end

  @doc """
  Revokes (deactivates) an API key.

  ## Parameters

    - `user_id` - The user ID performing the revoke
    - `api_key_id` - The API key ID to revoke

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :not_found}` if API key doesn't exist
    `{:error, :forbidden}` if user doesn't own the API key

  """
  def revoke_api_key(user_id, api_key_id)
      when is_binary(user_id) and is_binary(api_key_id) do
    UseCases.RevokeApiKey.execute(user_id, api_key_id)
  end

  @doc """
  Verifies an API key token.

  ## Parameters

    - `plain_token` - The plain API key token to verify

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :invalid}` if token doesn't match or key doesn't exist
    `{:error, :inactive}` if key exists but is inactive

  """
  def verify_api_key(plain_token) when is_binary(plain_token) do
    UseCases.VerifyApiKey.execute(plain_token)
  end

  ## API Key Workspace Access

  @doc """
  Lists workspaces accessible via an API key.

  Returns workspaces that the user has access to AND are listed in the
  API key's workspace_access list.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `opts` - Required options:
      - `list_workspaces_for_user` - Function to list user's workspaces

  ## Returns

    `{:ok, workspaces}` - List of accessible workspaces with basic info

  """
  def list_accessible_workspaces(user, api_key, opts) do
    UseCases.ListAccessibleWorkspaces.execute(user, api_key, opts)
  end

  @doc """
  Gets a workspace with documents and projects via API key.

  Retrieves workspace details including documents and projects. The API key
  acts as its owner, so documents and projects are filtered by user access.
  All queries use workspace slug, not ID.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace to retrieve
    - `opts` - Required options:
      - `get_workspace_by_slug` - Function (user, slug -> {:ok, workspace} | {:error, reason})
      - `list_documents_by_slug` - Function (user, workspace_slug -> [document])
      - `list_projects_by_slug` - Function (user, workspace_slug -> [project])

  ## Returns

    - `{:ok, workspace_data}` - Workspace with documents and projects
    - `{:error, :forbidden}` - API key lacks workspace access
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, :unauthorized}` - User doesn't have access to workspace

  """
  def get_workspace_with_details(user, api_key, workspace_slug, opts) do
    UseCases.GetWorkspaceWithDetails.execute(user, api_key, workspace_slug, opts)
  end

  @doc """
  Creates a project in a workspace via API key.

  The API key must have access to the workspace and the user must have
  permission to create projects in that workspace.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace
    - `attrs` - Project attributes (name, description, etc.)
    - `opts` - Required options:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `create_project` - Function (user, workspace_id, attrs -> {:ok, project} | {:error, reason})

  ## Returns

    - `{:ok, project}` - Project created successfully
    - `{:error, :forbidden}` - API key lacks workspace access or user lacks permission
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, changeset}` - Validation error

  """
  def create_project_via_api(user, api_key, workspace_slug, attrs, opts) do
    UseCases.CreateProjectViaApi.execute(user, api_key, workspace_slug, attrs, opts)
  end

  @doc """
  Gets a project with its documents via API key.

  Retrieves project details including associated documents. The API key
  acts as its owner, so documents are filtered by user access.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace
    - `project_slug` - The slug of the project to retrieve
    - `opts` - Required options:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `get_project_by_slug` - Function (user, workspace_id, project_slug -> {:ok, project} | {:error, reason})
      - `list_documents_for_project` - Function (user, workspace_id, project_id -> [document])

  ## Returns

    - `{:ok, %{project: project, documents: documents}}` - Project with documents
    - `{:error, :forbidden}` - API key lacks workspace access
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, :project_not_found}` - Project doesn't exist
    - `{:error, :unauthorized}` - User doesn't have access to workspace

  """
  def get_project_with_documents_via_api(user, api_key, workspace_slug, project_slug, opts) do
    UseCases.GetProjectWithDocumentsViaApi.execute(
      user,
      api_key,
      workspace_slug,
      project_slug,
      opts
    )
  end
end

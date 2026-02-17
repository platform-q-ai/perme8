defmodule Identity do
  @moduledoc """
  Public API for identity and account management operations.

  This context module serves as a thin facade over the Identity bounded context,
  delegating complex operations to use cases in the application layer while
  providing simple data access for reads.

  ## Architecture

  - **Simple reads** -> Direct database queries via Repo
  - **Complex operations** -> Delegated to use cases in `Application.UseCases`
  - **Business rules** -> Encapsulated in domain policies

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
  """

  # Top-level boundary for identity context
  # The Identity app is self-contained with its own domain, application,
  # and infrastructure layers, but we don't enforce strict internal
  # layer boundaries to keep configuration simple.
  use Boundary,
    top_level?: true,
    deps: [
      # Application layer (use cases, services)
      Identity.ApplicationLayer,
      # Shared infrastructure
      Identity.Repo,
      Identity.Mailer
    ],
    exports: [
      # Domain entities and policies that other apps may need
      Domain.Entities.User,
      Domain.Entities.ApiKey,
      Domain.Entities.UserToken,
      Domain.Entities.Workspace,
      Domain.Entities.WorkspaceMember,
      Domain.Policies.AuthenticationPolicy,
      Domain.Policies.TokenPolicy,
      Domain.Policies.ApiKeyPolicy,
      Domain.Policies.MembershipPolicy,
      Domain.Policies.WorkspacePermissionsPolicy,
      Domain.Services.TokenBuilder,
      Domain.Services.SlugGenerator,
      Domain.Scope,
      # Infrastructure schemas exported for test fixtures and cross-app integration
      # These are needed by Jarga.AccountsFixtures for creating test data
      Infrastructure.Schemas.UserSchema,
      Infrastructure.Schemas.UserTokenSchema,
      Infrastructure.Schemas.ApiKeySchema,
      Infrastructure.Schemas.WorkspaceSchema,
      Infrastructure.Schemas.WorkspaceMemberSchema,
      # Application services exported for test fixtures
      Application.Services.PasswordService,
      Application.Services.ApiKeyTokenService
    ]

  import Ecto.Query, warn: false
  alias Identity.Repo

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Policies.AuthenticationPolicy
  alias Identity.Infrastructure.Queries.TokenQueries
  alias Identity.Infrastructure.Schemas.{UserSchema, UserTokenSchema}
  alias Identity.Application.UseCases

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
    query =
      from(u in UserSchema,
        where: fragment("lower(?)", u.email) == ^String.downcase(email)
      )

    case Repo.one(query) do
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
    {:ok, query} = TokenQueries.verify_session_token_query(token)

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
    with {:ok, query} <- TokenQueries.verify_magic_link_token_query(token),
         {user_schema, _token} <- Repo.one(query) do
      User.from_schema(user_schema)
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link token.

  Delegates to `UseCases.LoginByMagicLink` which handles three cases:
  1. Confirmed user -> login and expire token
  2. Unconfirmed user without password -> confirm, login, expire all tokens
  3. Unconfirmed user with password -> confirm, login, expire token

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
  def deliver_user_update_email_instructions(
        %{id: _, email: _} = user,
        current_email,
        update_email_url_fun
      )
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
  def deliver_login_instructions(%{id: _, email: _} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    UseCases.DeliverLoginInstructions.execute(%{
      user: user,
      url_fun: magic_link_url_fun
    })
  end

  @doc """
  Delivers password reset instructions to the user.

  Generates a reset password token and sends an email with a link to reset
  the password. The token is valid for 1 hour.

  ## Parameters

    - `user` - User struct with id and email
    - `reset_password_url_fun` - Function that takes a token and returns a URL

  ## Returns

    `{:ok, email}` on success

  ## Examples

      iex> deliver_reset_password_instructions(user, &"/users/reset-password/\#{&1}")
      {:ok, %Swoosh.Email{}}

  """
  def deliver_reset_password_instructions(%{id: _, email: _} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    UseCases.DeliverResetPasswordInstructions.execute(%{
      user: user,
      url_fun: reset_password_url_fun
    })
  end

  @doc """
  Gets the user by reset password token.

  Returns `nil` if the token is invalid or expired.

  ## Parameters

    - `token` - The URL-encoded reset password token

  ## Returns

    User struct or nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- TokenQueries.verify_reset_password_token_query(token),
         user_schema when not is_nil(user_schema) <- Repo.one(query) do
      User.from_schema(user_schema)
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password using a reset token.

  This verifies the token, updates the password, and deletes all tokens
  for the user (invalidating all sessions).

  ## Parameters

    - `token` - The reset password token
    - `attrs` - Map with :password and :password_confirmation

  ## Returns

    - `{:ok, user}` on success
    - `{:error, :invalid_token}` if token is invalid/expired
    - `{:error, changeset}` if password validation fails

  """
  def reset_user_password(token, attrs) do
    UseCases.ResetUserPassword.execute(%{token: token, attrs: attrs})
  end

  @doc """
  Deletes the session token.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(TokenQueries.tokens_by_token_and_context(token, "session"))
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

  @doc """
  Resolves a workspace slug to its UUID.

  If the given string is already a valid UUID, returns it as-is.
  Otherwise, looks up the workspace by slug and returns the ID.

  ## Examples

      iex> Identity.resolve_workspace_id("product-team")
      {:ok, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee01"}

      iex> Identity.resolve_workspace_id("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee01")
      {:ok, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee01"}

      iex> Identity.resolve_workspace_id("nonexistent")
      {:error, :not_found}
  """
  def resolve_workspace_id(slug_or_id) when is_binary(slug_or_id) do
    if uuid?(slug_or_id) do
      {:ok, slug_or_id}
    else
      case Repo.one(
             from(w in Identity.Infrastructure.Schemas.WorkspaceSchema,
               where: w.slug == ^slug_or_id,
               select: w.id
             )
           ) do
        nil -> {:error, :not_found}
        id -> {:ok, id}
      end
    end
  end

  defp uuid?(str) do
    case Ecto.UUID.cast(str) do
      {:ok, _} -> true
      :error -> false
    end
  end

  ## Workspaces

  alias Identity.Domain.Entities.{Workspace, WorkspaceMember}
  alias Identity.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}
  alias Identity.Infrastructure.Queries.WorkspaceQueries
  alias Identity.Domain.Services.SlugGenerator
  alias Identity.Infrastructure.Repositories.MembershipRepository
  alias Identity.Domain.Policies.WorkspacePermissionsPolicy

  alias Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier

  @doc """
  Returns the list of workspaces for a given user.

  Only returns non-archived workspaces where the user is a member.
  """
  def list_workspaces_for_user(%{id: _} = user) do
    WorkspaceQueries.base()
    |> WorkspaceQueries.for_user(user)
    |> WorkspaceQueries.active()
    |> WorkspaceQueries.ordered()
    |> Repo.all()
    |> Enum.map(&Workspace.from_schema/1)
  end

  @doc """
  Creates a workspace for a user.

  Automatically adds the creating user as an owner of the workspace.
  """
  def create_workspace(%User{} = user, attrs) do
    Repo.transact(fn ->
      with {:ok, workspace} <- create_workspace_record(attrs),
           {:ok, _member} <- add_member_as_owner(workspace, user) do
        {:ok, workspace}
      end
    end)
  end

  defp create_workspace_record(attrs) do
    # Generate slug in context before passing to changeset (business logic)
    # Only generate slug if name is present
    name = attrs["name"] || attrs[:name]

    attrs_with_slug =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> then(fn normalized_attrs ->
        if name do
          slug = SlugGenerator.generate(name, &MembershipRepository.slug_exists?/2)
          Map.put(normalized_attrs, "slug", slug)
        else
          normalized_attrs
        end
      end)

    %WorkspaceSchema{}
    |> WorkspaceSchema.changeset(attrs_with_slug)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp add_member_as_owner(workspace, user) do
    now = DateTime.utc_now()

    %WorkspaceMemberSchema{}
    |> WorkspaceMemberSchema.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: :owner,
      invited_at: now,
      joined_at: now
    })
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Gets a single workspace for a user.

  Returns `{:ok, workspace}` if the user is a member, or an error tuple otherwise.
  """
  def get_workspace(%User{} = user, id) do
    case MembershipRepository.get_workspace_for_user(user, id) do
      nil ->
        if MembershipRepository.workspace_exists?(id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  @doc """
  Gets a single workspace for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.
  """
  def get_workspace!(%User{} = user, id) do
    WorkspaceQueries.for_user_by_id(user, id)
    |> Repo.one!()
    |> Workspace.from_schema()
  end

  @doc """
  Gets a single workspace by slug for a user.

  Returns `{:ok, workspace}` if the user is a member, or an error tuple otherwise.
  """
  def get_workspace_by_slug(%User{} = user, slug) do
    case MembershipRepository.get_workspace_for_user_by_slug(user, slug) do
      nil ->
        {:error, :workspace_not_found}

      workspace ->
        {:ok, workspace}
    end
  end

  @doc """
  Gets a workspace by slug with the current user's member record.

  Returns `{:ok, workspace, member}` if the user is a member, or
  `{:error, :workspace_not_found}` otherwise.
  """
  def get_workspace_and_member_by_slug(%User{} = user, slug) do
    case MembershipRepository.get_workspace_and_member_by_slug(user, slug) do
      nil ->
        {:error, :workspace_not_found}

      {workspace, member} ->
        {:ok, workspace, member}
    end
  end

  @doc """
  Gets a single workspace by slug for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.
  """
  def get_workspace_by_slug!(%User{} = user, slug) do
    WorkspaceQueries.for_user_by_slug(user, slug)
    |> Repo.one!()
    |> Workspace.from_schema()
  end

  @doc """
  Updates a workspace for a user.

  The user must be a member of the workspace with permission to edit it.
  Only admins and owners can edit workspaces.
  """
  def update_workspace(%User{} = user, workspace_id, attrs, opts \\ []) do
    # Get notifier from opts or use default
    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    with {:ok, member} <- get_member(user, workspace_id),
         :ok <- authorize_edit_workspace(member.role) do
      case get_workspace(user, workspace_id) do
        {:ok, workspace} ->
          result =
            workspace
            |> WorkspaceSchema.to_schema()
            |> WorkspaceSchema.changeset(attrs)
            |> Repo.update()

          # Notify workspace members via injected notifier
          case result do
            {:ok, schema} ->
              updated_workspace = Workspace.from_schema(schema)
              notifier.notify_workspace_updated(updated_workspace)
              {:ok, updated_workspace}

            error ->
              error
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp authorize_edit_workspace(role) do
    if WorkspacePermissionsPolicy.can?(role, :edit_workspace) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Deletes a workspace for a user.

  The user must be the owner of the workspace to delete it.
  Only owners can delete workspaces.
  """
  def delete_workspace(%User{} = user, workspace_id) do
    with {:ok, member} <- get_member(user, workspace_id),
         :ok <- authorize_delete_workspace(member.role) do
      case get_workspace(user, workspace_id) do
        {:ok, workspace} ->
          workspace
          |> WorkspaceSchema.to_schema()
          |> Repo.delete()
          |> case do
            {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
            {:error, changeset} -> {:error, changeset}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp authorize_delete_workspace(role) do
    if WorkspacePermissionsPolicy.can?(role, :delete_workspace) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Verifies that a user is a member of a workspace.

  This is a public API for other contexts to verify workspace membership.
  """
  def verify_membership(%User{} = user, workspace_id) do
    get_workspace(user, workspace_id)
  end

  @doc """
  Checks if a user is a member of a workspace by workspace ID.
  """
  def member?(user_id, workspace_id) do
    MembershipRepository.member?(user_id, workspace_id)
  end

  @doc """
  Checks if a user is a member of a workspace by workspace slug.
  """
  def member_by_slug?(user_id, workspace_slug) do
    MembershipRepository.member_by_slug?(user_id, workspace_slug)
  end

  @doc """
  Gets a user's workspace member record.

  Returns `{:ok, workspace_member}` or `{:error, reason}`.
  """
  def get_member(%User{} = user, workspace_id) do
    case MembershipRepository.get_member(user, workspace_id) do
      nil ->
        if MembershipRepository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      member ->
        {:ok, member}
    end
  end

  @doc """
  Invites a user to join a workspace via email.

  The inviter must be a member of the workspace. Only admin, member, and guest
  roles are allowed (owner role is reserved for workspace creators).
  """
  def invite_member(%User{} = inviter, workspace_id, email, role, opts \\ []) do
    # Get notifier from opts or use default
    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    params = %{
      inviter: inviter,
      workspace_id: workspace_id,
      email: email,
      role: role
    }

    # Delegate to use case
    UseCases.InviteMember.execute(params, notifier: notifier)
  end

  @doc """
  Lists all members of a workspace.

  Note: This function does not verify that the caller is a member of the workspace.
  Callers are responsible for ensuring the user has access to the workspace before
  calling this function. Consider adding a `list_members/2` variant that accepts
  the caller user and verifies membership.
  """
  def list_members(workspace_id) do
    MembershipRepository.list_members(workspace_id)
  end

  @doc """
  Accepts all pending workspace invitations for a user.

  When a user signs up with an email that has pending workspace invitations,
  this function converts those pending invitations into active memberships.
  """
  def accept_pending_invitations(%User{} = user) do
    Repo.transact(fn ->
      # Find all pending invitations for this user's email (case-insensitive)
      pending_invitations =
        WorkspaceQueries.find_pending_invitations_by_email(user.email)
        |> Repo.all()

      # Update each invitation to accept it
      now = DateTime.utc_now()

      accepted =
        Enum.map(pending_invitations, fn invitation ->
          invitation
          |> WorkspaceMemberSchema.changeset(%{
            user_id: user.id,
            joined_at: now
          })
          |> Repo.update!()
          |> WorkspaceMember.from_schema()
        end)

      {:ok, accepted}
    end)
  end

  @doc """
  Accepts a specific workspace invitation for a user.

  Finds a pending invitation (not yet joined) for the given workspace and user,
  and marks it as accepted by setting the user_id and joined_at timestamp.
  """
  def accept_invitation_by_workspace(workspace_id, user_id) do
    Repo.transact(fn ->
      case find_pending_invitation_record(workspace_id, user_id) do
        {:error, reason} -> {:error, reason}
        {:ok, workspace_member} -> accept_invitation_record(workspace_member, user_id)
      end
    end)
  end

  defp find_pending_invitation_record(workspace_id, user_id) do
    case WorkspaceQueries.find_pending_invitation(workspace_id, user_id) |> Repo.one() do
      nil -> {:error, :invitation_not_found}
      workspace_member -> {:ok, workspace_member}
    end
  end

  defp accept_invitation_record(workspace_member, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    workspace_member
    |> WorkspaceMemberSchema.accept_invitation_changeset(%{
      user_id: user_id,
      joined_at: now
    })
    |> Repo.update()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Declines a specific workspace invitation for a user.

  Finds and deletes a pending invitation for the given workspace and user.
  """
  def decline_invitation_by_workspace(workspace_id, user_id) do
    # Find and delete the pending workspace_member record
    case WorkspaceQueries.find_pending_invitation(workspace_id, user_id) |> Repo.one() do
      nil ->
        # Invitation not found is OK - might have been deleted already
        :ok

      workspace_member ->
        case Repo.delete(workspace_member) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Lists all pending workspace invitations for a user's email.

  Returns invitations with workspace and inviter associations preloaded.
  """
  def list_pending_invitations_with_details(email) do
    WorkspaceQueries.find_pending_invitations_by_email(email)
    |> WorkspaceQueries.with_workspace_and_inviter()
    |> Repo.all()

    # Return schemas directly to preserve workspace and inviter associations
    # These are needed for notification creation
  end

  @doc """
  Creates notifications for all pending workspace invitations for a user.
  """
  def create_notifications_for_pending_invitations(%User{} = user) do
    UseCases.CreateNotificationsForPendingInvitations.execute(%{user: user})
  end

  @doc """
  Changes a workspace member's role.

  The actor must be a member of the workspace. Cannot change the owner's role,
  and cannot assign the owner role.
  """
  def change_member_role(%User{} = actor, workspace_id, member_email, new_role) do
    params = %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email,
      new_role: new_role
    }

    UseCases.ChangeMemberRole.execute(params)
  end

  @doc """
  Removes a member from a workspace.

  The actor must be a member of the workspace. Cannot remove the owner.
  """
  def remove_member(%User{} = actor, workspace_id, member_email) do
    params = %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email
    }

    UseCases.RemoveMember.execute(params)
  end

  @doc """
  Creates a changeset for a new workspace (for form validation).
  """
  def change_workspace do
    WorkspaceSchema.changeset(%WorkspaceSchema{}, %{})
  end

  @doc """
  Creates a changeset for editing a workspace (for form validation).
  """
  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    workspace
    |> WorkspaceSchema.to_schema()
    |> WorkspaceSchema.changeset(attrs)
  end
end

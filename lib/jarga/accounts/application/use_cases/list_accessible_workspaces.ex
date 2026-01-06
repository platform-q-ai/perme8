defmodule Jarga.Accounts.Application.UseCases.ListAccessibleWorkspaces do
  @moduledoc """
  Use case for listing workspaces accessible to an API key.

  This use case retrieves all workspaces that an API key has been granted
  access to, filtered by the workspace_access slugs stored in the API key.

  The API key acts as its owner (user), so it uses the same authorization
  as the user would have. The workspace_access list further restricts
  which of the user's workspaces can be accessed via this specific API key.

  ## Dependency Injection

  The use case REQUIRES a `list_workspaces_for_user` function via opts.
  This maintains Clean Architecture boundaries - the Accounts context
  does not depend on the Workspaces context. The caller (controller)
  provides the workspace fetching function.
  """

  alias Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy

  @doc """
  Executes the list accessible workspaces use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `opts` - Required options:
      - `list_workspaces_for_user` - Function (user -> [workspace]) for fetching user's workspaces

  ## Returns

    `{:ok, workspaces}` on success where workspaces is a list of workspace entities
    filtered to only those the API key has access to (based on workspace_access slugs)

  ## Examples

      iex> api_key = %ApiKey{workspace_access: ["product-team", "engineering"]}
      iex> opts = [list_workspaces_for_user: &Workspaces.list_workspaces_for_user/1]
      iex> ListAccessibleWorkspaces.execute(user, api_key, opts)
      {:ok, [%Workspace{name: "Product Team"}, %Workspace{name: "Engineering"}]}

      iex> api_key = %ApiKey{workspace_access: []}
      iex> ListAccessibleWorkspaces.execute(user, api_key, opts)
      {:ok, []}

  """
  @spec execute(map(), map(), keyword()) :: {:ok, list(map())}
  def execute(user, api_key, opts \\ [])

  def execute(_user, %{workspace_access: nil}, _opts), do: {:ok, []}
  def execute(_user, %{workspace_access: []}, _opts), do: {:ok, []}

  def execute(user, api_key, opts) do
    list_workspaces_fn = Keyword.fetch!(opts, :list_workspaces_for_user)

    # Get all workspaces the user has access to
    all_user_workspaces = list_workspaces_fn.(user)

    # Filter to only those the API key is allowed to access
    accessible_workspaces =
      WorkspaceAccessPolicy.list_accessible_workspaces(api_key, all_user_workspaces)

    {:ok, accessible_workspaces}
  end
end

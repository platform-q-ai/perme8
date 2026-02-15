defmodule Identity.Domain.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Identity.Domain.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  defstruct user: nil, workspace: nil

  @doc """
  Creates a scope for the given user.

  Accepts any user struct (Identity.Domain.Entities.User or Jarga.Accounts.Domain.Entities.User)
  as long as it has an `id` field. The workspace defaults to nil.

  Returns nil if no user is given.
  """
  def for_user(%{id: _} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for the given user and workspace.

  Sets both the user and workspace context, useful for workspace-scoped operations.
  """
  def for_user_and_workspace(%{id: _} = user, %{id: _} = workspace) do
    %__MODULE__{user: user, workspace: workspace}
  end
end

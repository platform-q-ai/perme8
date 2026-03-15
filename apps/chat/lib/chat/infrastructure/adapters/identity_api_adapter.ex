defmodule Chat.Infrastructure.Adapters.IdentityApiAdapter do
  @moduledoc """
  Infrastructure adapter that validates cross-app references by calling
  Identity's public facade API.

  Implements `IdentityApiBehaviour` so it can be injected into use cases
  and swapped with a Mox mock in tests.
  """

  @behaviour Chat.Application.Behaviours.IdentityApiBehaviour

  @impl true
  def user_exists?(user_id) do
    case Identity.get_user(user_id) do
      nil -> false
      _user -> true
    end
  end

  @impl true
  def validate_workspace_access(user_id, workspace_id) do
    if Identity.member?(user_id, workspace_id) do
      :ok
    else
      {:error, :not_a_member}
    end
  end
end

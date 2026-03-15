defmodule Chat.Application.Behaviours.IdentityApiBehaviour do
  @moduledoc """
  Port defining callbacks for Identity validation in the Chat context.

  Used by CreateSession to verify that cross-app references (user_id, workspace_id)
  are valid before creating a chat session. Implementations call Identity's public
  facade API; tests inject a Mox mock.
  """

  @callback user_exists?(user_id :: String.t()) :: boolean()

  @callback validate_workspace_access(user_id :: String.t(), workspace_id :: String.t()) ::
              :ok | {:error, :workspace_not_found | :not_a_member}
end

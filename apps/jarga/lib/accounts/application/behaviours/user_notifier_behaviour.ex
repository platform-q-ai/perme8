defmodule Jarga.Accounts.Application.Behaviours.UserNotifierBehaviour do
  @moduledoc """
  Behaviour defining the user notifier contract.
  """

  alias Jarga.Accounts.Domain.Entities.User

  @callback deliver_login_instructions(User.t(), String.t()) :: {:ok, map()}
  @callback deliver_update_email_instructions(User.t(), String.t()) :: {:ok, map()}
end

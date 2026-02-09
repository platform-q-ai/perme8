defmodule Identity.Application.Behaviours.UserNotifierBehaviour do
  @moduledoc """
  Behaviour defining the user notifier contract.
  """

  alias Identity.Domain.Entities.User

  @callback deliver_login_instructions(User.t(), String.t(), keyword()) :: {:ok, map()}
  @callback deliver_update_email_instructions(User.t(), String.t(), keyword()) :: {:ok, map()}
end

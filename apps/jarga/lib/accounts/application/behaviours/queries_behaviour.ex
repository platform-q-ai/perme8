defmodule Jarga.Accounts.Application.Behaviours.QueriesBehaviour do
  @moduledoc """
  Behaviour defining the account queries contract.
  """

  @type user_id :: String.t()
  @type token :: String.t()
  @type context :: String.t()
  @type token_id :: String.t()

  @callback verify_magic_link_token_query(token) :: {:ok, Ecto.Query.t()} | :error
  @callback verify_change_email_token_query(token, context) :: {:ok, Ecto.Query.t()} | :error
  @callback tokens_by_ids([token_id]) :: Ecto.Query.t()
  @callback tokens_for_user_and_context(user_id, context) :: Ecto.Query.t()
end

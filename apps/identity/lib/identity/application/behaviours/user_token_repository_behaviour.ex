defmodule Identity.Application.Behaviours.UserTokenRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the user token repository contract.
  """

  alias Identity.Domain.Entities.UserToken

  @type repo :: module()
  @type user_id :: String.t()

  @callback insert!(UserToken.t(), repo) :: UserToken.t()
  @callback delete!(UserToken.t(), repo) :: UserToken.t()
  @callback all_by_user_id(user_id, repo) :: [UserToken.t()]
  @callback delete_all(Ecto.Query.t(), repo) :: {non_neg_integer(), nil}
  @callback get_one(Ecto.Query.t(), repo) :: UserToken.t() | nil
end

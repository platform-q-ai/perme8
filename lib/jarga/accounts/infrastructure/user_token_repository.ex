defmodule Jarga.Accounts.Infrastructure.UserTokenRepository do
  @moduledoc """
  Infrastructure layer for UserToken data access.
  Provides database query execution functions for user tokens.
  """

  alias Jarga.Repo

  @doc """
  Executes a query and returns a single user token.

  Returns the token if found, nil otherwise.

  ## Examples

      iex> get_one(query)
      %UserToken{}

      iex> get_one(query)
      nil

  """
  def get_one(query) do
    Repo.one(query)
  end
end

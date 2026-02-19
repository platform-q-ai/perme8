defmodule Agents.Application.Behaviours.IdentityBehaviour do
  @moduledoc """
  Behaviour defining the contract for Identity operations.

  Enables mocking in use case tests by abstracting Identity.verify_api_key/1
  and workspace resolution behind a behaviour interface.
  """

  alias Identity.Domain.Entities.ApiKey
  alias Identity.Domain.Entities.User

  @callback verify_api_key(plain_token :: String.t()) ::
              {:ok, ApiKey.t()} | {:error, :invalid} | {:error, :inactive}

  @callback resolve_workspace_id(slug_or_id :: String.t()) ::
              {:ok, String.t()} | {:error, :not_found}

  @callback get_user(user_id :: String.t()) ::
              {:ok, User.t()} | {:error, :user_not_found}
end

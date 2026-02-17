defmodule KnowledgeMcp.Application.Behaviours.IdentityBehaviour do
  @moduledoc """
  Behaviour defining the contract for Identity operations.

  Enables mocking in use case tests by abstracting Identity.verify_api_key/1
  behind a behaviour interface.
  """

  alias Identity.Domain.Entities.ApiKey

  @callback verify_api_key(plain_token :: String.t()) ::
              {:ok, ApiKey.t()} | {:error, :invalid} | {:error, :inactive}
end

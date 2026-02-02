defmodule Jarga.Accounts.Application.Behaviours.ApiKeyRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the API key repository contract.

  This behaviour defines what the Application layer needs from the data layer,
  expressed in terms of domain entities (not infrastructure schemas).

  ## Clean Architecture

  - Defined in Application layer (what we need)
  - Implemented in Infrastructure layer (how it's done)
  - Use cases receive implementations via dependency injection

  ## Usage in Use Cases

      def execute(user_id, attrs, opts \\\\ []) do
        api_key_repo = Keyword.get(opts, :api_key_repo, default_api_key_repo())
        repo = Keyword.get(opts, :repo, Jarga.Repo)

        case api_key_repo.insert(repo, attrs) do
          {:ok, api_key} -> ...
        end
      end

      defp default_api_key_repo do
        Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
      end
  """

  alias Jarga.Accounts.Domain.Entities.ApiKey

  @type repo :: module()
  @type attrs :: map()
  @type id :: String.t()
  @type user_id :: String.t()
  @type hashed_token :: String.t()

  @doc "Inserts a new API key and returns the domain entity."
  @callback insert(repo, attrs) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}

  @doc "Updates an API key by ID and returns the domain entity."
  @callback update(repo, id, attrs) ::
              {:ok, ApiKey.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}

  @doc "Gets an API key by ID."
  @callback get_by_id(repo, id) :: {:ok, ApiKey.t()} | {:error, :not_found}

  @doc "Gets an API key by hashed token."
  @callback get_by_hashed_token(repo, hashed_token) :: {:ok, ApiKey.t()} | {:error, :not_found}

  @doc "Lists all API keys for a user."
  @callback list_by_user_id(repo, user_id) :: {:ok, [ApiKey.t()]}

  @doc "Checks if an API key exists by ID and hashed token."
  @callback exists_by_id_and_hashed_token?(repo, id, hashed_token) :: boolean()

  @doc "Deletes all API keys for a user."
  @callback delete_by_user_id(repo, user_id) :: {non_neg_integer(), nil}
end

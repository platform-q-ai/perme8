defmodule Agents.Application.Behaviours.JargaGatewayBehaviour do
  @moduledoc """
  Behaviour defining the contract for Jarga operations.

  Enables mocking in use case tests by abstracting Jarga workspace, project,
  and document operations behind a behaviour interface.
  """

  @callback list_workspaces(user_id :: String.t()) ::
              {:ok, [map()]} | {:error, term()}

  @callback get_workspace(user_id :: String.t(), workspace_slug :: String.t()) ::
              {:ok, map()} | {:error, :not_found | :unauthorized}

  @callback list_projects(user_id :: String.t(), workspace_id :: String.t()) ::
              {:ok, [map()]} | {:error, term()}

  @callback create_project(user_id :: String.t(), workspace_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback get_project(user_id :: String.t(), workspace_id :: String.t(), slug :: String.t()) ::
              {:ok, map()} | {:error, :project_not_found}

  @callback list_documents(user_id :: String.t(), workspace_id :: String.t(), opts :: keyword()) ::
              {:ok, [map()]} | {:error, term()}

  @callback create_document(user_id :: String.t(), workspace_id :: String.t(), attrs :: map()) ::
              {:ok, map()} | {:error, term()}

  @callback get_document(user_id :: String.t(), workspace_id :: String.t(), slug :: String.t()) ::
              {:ok, map()} | {:error, :document_not_found | :forbidden}
end

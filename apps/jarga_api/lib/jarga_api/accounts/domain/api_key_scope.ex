defmodule JargaApi.Accounts.Domain.ApiKeyScope do
  @moduledoc """
  Interprets API key access scopes in the context of Jarga's domain.

  Identity stores API keys with a generic `workspace_access` field containing
  a list of string identifiers. This module interprets those identifiers as
  workspace slugs within Jarga's domain.

  All functions are pure and deterministic with zero infrastructure dependencies.

  ## Design Notes

  This module exists because:
  - Identity owns API keys but doesn't understand what "workspaces" are
  - Jarga owns workspaces and interprets the access scope
  - The `workspace_access` field is just a list of strings to Identity

  """

  @doc """
  Validates that a scope list is well-formed.

  A scope list is valid if:
  - It is a list (can be empty)
  - All items are non-nil strings
  - No duplicate entries

  ## Parameters

    - `scope_list` - List of scope identifiers (workspace slugs)

  ## Returns

  - `:ok` - Scope list is valid
  - `:error` - Scope list is invalid

  ## Examples

      iex> ApiKeyScope.valid?([])
      :ok

      iex> ApiKeyScope.valid?(["workspace1", "workspace2"])
      :ok

      iex> ApiKeyScope.valid?(["workspace1", "workspace1"])
      :error

      iex> ApiKeyScope.valid?(["workspace1", nil])
      :error

  """
  def valid?(scope_list) when is_list(scope_list) do
    cond do
      Enum.any?(scope_list, &is_nil/1) -> :error
      length(scope_list) != length(Enum.uniq(scope_list)) -> :error
      true -> :ok
    end
  end

  @doc """
  Checks if an API key's scope includes access to a specific workspace.

  ## Parameters

    - `api_key` - Map with `workspace_access` field (list of workspace slugs)
    - `workspace_slug` - The workspace slug to check

  ## Returns

  Boolean indicating if the API key has access to the workspace

  ## Examples

      iex> api_key = %{workspace_access: ["product-team", "engineering"]}
      iex> ApiKeyScope.includes?(api_key, "product-team")
      true

      iex> ApiKeyScope.includes?(api_key, "marketing")
      false

      iex> api_key = %{workspace_access: []}
      iex> ApiKeyScope.includes?(api_key, "any")
      false

  """
  def includes?(%{workspace_access: nil}, _workspace_slug), do: false
  def includes?(%{workspace_access: []}, _workspace_slug), do: false

  def includes?(%{workspace_access: scope_list}, workspace_slug) do
    workspace_slug in scope_list
  end

  @doc """
  Filters workspaces to only those within the API key's scope.

  ## Parameters

    - `api_key` - Map with `workspace_access` field
    - `workspaces` - List of workspace entities with `slug` field

  ## Returns

  List of workspaces that are within the API key's scope

  ## Examples

      iex> api_key = %{workspace_access: ["product-team"]}
      iex> workspaces = [%{slug: "product-team"}, %{slug: "engineering"}]
      iex> ApiKeyScope.filter_workspaces(api_key, workspaces)
      [%{slug: "product-team"}]

      iex> api_key = %{workspace_access: []}
      iex> ApiKeyScope.filter_workspaces(api_key, workspaces)
      []

  """
  @spec filter_workspaces(map(), list()) :: list()
  def filter_workspaces(%{workspace_access: nil}, _workspaces), do: []
  def filter_workspaces(%{workspace_access: []}, _workspaces), do: []

  def filter_workspaces(%{workspace_access: scope_list}, workspaces) do
    Enum.filter(workspaces, fn workspace ->
      workspace.slug in scope_list
    end)
  end
end

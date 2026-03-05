defmodule Identity.Domain.Policies.ApiKeyPermissionPolicy do
  @moduledoc """
  Pure business rules for API key permission scope matching.
  """

  @scope_format ~r/^(\*|[a-z_]+:[a-z_.*]+)$/

  @all_scopes [
    "agents:read",
    "agents:write",
    "agents:query",
    "mcp:knowledge.search",
    "mcp:knowledge.get",
    "mcp:knowledge.traverse",
    "mcp:knowledge.create",
    "mcp:knowledge.update",
    "mcp:knowledge.relate",
    "mcp:jarga.list_workspaces",
    "mcp:jarga.get_workspace",
    "mcp:jarga.list_projects",
    "mcp:jarga.create_project",
    "mcp:jarga.get_project",
    "mcp:jarga.list_documents",
    "mcp:jarga.create_document",
    "mcp:jarga.get_document"
  ]

  @presets %{
    "Full Access" => ["*"],
    "Read Only" => [
      "agents:read",
      "mcp:knowledge.search",
      "mcp:knowledge.get",
      "mcp:knowledge.traverse",
      "mcp:jarga.list_workspaces",
      "mcp:jarga.get_workspace",
      "mcp:jarga.list_projects",
      "mcp:jarga.get_project",
      "mcp:jarga.list_documents",
      "mcp:jarga.get_document"
    ],
    "Agent Operator" => ["agents:read", "agents:write", "agents:query"]
  }

  @read_only_set MapSet.new(@presets["Read Only"])
  @agent_operator_set MapSet.new(@presets["Agent Operator"])

  @doc """
  Returns true when the required scope is allowed by the permissions list.

  `nil` permissions are treated as full access for backward compatibility.
  """
  def has_permission?(nil, _required_scope), do: true

  def has_permission?(permissions, required_scope)
      when is_list(permissions) and is_binary(required_scope) do
    Enum.any?(permissions, &scope_matches?(&1, required_scope))
  end

  @doc """
  Returns a normalized permission summary for UI display.
  """
  def permission_summary(nil), do: :full_access
  def permission_summary(["*"]), do: :full_access
  def permission_summary([]), do: :no_access

  def permission_summary(permissions) when is_list(permissions) do
    permission_set = MapSet.new(permissions)

    cond do
      MapSet.equal?(permission_set, @read_only_set) -> :read_only
      MapSet.equal?(permission_set, @agent_operator_set) -> :agent_operator
      true -> {:custom, length(permissions)}
    end
  end

  @doc """
  Validates whether a scope string matches the supported format.
  """
  def valid_scope?(scope) when is_binary(scope), do: Regex.match?(@scope_format, scope)
  def valid_scope?(_scope), do: false

  @doc """
  Returns named permission presets.
  """
  def presets, do: @presets

  @doc """
  Returns all concrete REST and MCP scopes.
  """
  def all_scopes, do: @all_scopes

  defp scope_matches?("*", _required_scope), do: true
  defp scope_matches?(permission, required_scope) when permission == required_scope, do: true

  defp scope_matches?(permission, required_scope) do
    cond do
      String.ends_with?(permission, ":*") ->
        prefix = String.trim_trailing(permission, "*")
        String.starts_with?(required_scope, prefix)

      String.ends_with?(permission, ".*") ->
        prefix = String.trim_trailing(permission, "*")
        String.starts_with?(required_scope, prefix)

      true ->
        false
    end
  end
end

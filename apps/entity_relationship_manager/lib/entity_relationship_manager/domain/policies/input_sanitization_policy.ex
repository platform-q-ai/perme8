defmodule EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy do
  @moduledoc """
  Domain policy for sanitizing and validating user input.

  Pure functions that validate type names, UUIDs, and other input formats
  to prevent injection attacks and ensure data integrity.

  NO I/O, NO database, NO side effects.
  """

  @type_name_pattern ~r/^[a-zA-Z][a-zA-Z0-9_]*$/
  @max_type_name_length 100
  @uuid_pattern ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

  @doc """
  Validates a type name (entity type or edge type).

  Valid type names:
  - Start with a letter (a-z, A-Z)
  - Contain only alphanumeric characters and underscores
  - Are non-empty
  - Are at most #{@max_type_name_length} characters long
  """
  @spec validate_type_name(term()) :: :ok | {:error, String.t()}
  def validate_type_name(nil) do
    {:error, "type name cannot be nil"}
  end

  def validate_type_name(name) when is_binary(name) do
    cond do
      name == "" ->
        {:error, "type name cannot be empty"}

      String.length(name) > @max_type_name_length ->
        {:error, "type name must be at most #{@max_type_name_length} characters"}

      not Regex.match?(@type_name_pattern, name) ->
        {:error,
         "type name must start with a letter and contain only alphanumeric characters and underscores"}

      true ->
        :ok
    end
  end

  def validate_type_name(_name) do
    {:error, "type name must be a string"}
  end

  @doc """
  Validates a UUID string.

  Accepts standard UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
  where `x` is a hexadecimal character (case-insensitive).
  """
  @spec validate_uuid(term()) :: :ok | {:error, String.t()}
  def validate_uuid(uuid) when is_binary(uuid) do
    if Regex.match?(@uuid_pattern, uuid) do
      :ok
    else
      {:error, "invalid UUID format"}
    end
  end

  def validate_uuid(_uuid) do
    {:error, "UUID must be a string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}
  end
end

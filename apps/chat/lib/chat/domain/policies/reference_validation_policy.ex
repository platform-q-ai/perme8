defmodule Chat.Domain.Policies.ReferenceValidationPolicy do
  @moduledoc """
  Pure domain policy that interprets cross-app reference validation results.

  This module contains no I/O. It takes pre-fetched validation results as inputs
  and returns `:ok` or `{:error, reason}`.
  """

  @doc """
  Interprets the result of a user existence lookup.

  ## Parameters
    - `true` — user exists
    - `false` — user does not exist
    - `{:error, _}` — Identity was unreachable
  """
  @spec validate_user_reference(boolean() | {:error, term()}) ::
          :ok | {:error, :user_not_found | :identity_unavailable}
  def validate_user_reference(true), do: :ok
  def validate_user_reference(false), do: {:error, :user_not_found}
  def validate_user_reference({:error, _}), do: {:error, :identity_unavailable}

  @doc """
  Interprets the result of a workspace access validation.

  ## Parameters
    - `nil` — no workspace_id provided (optional field, always valid)
    - `:ok` — workspace exists and user has access
    - `{:error, reason}` — workspace invalid or user lacks access
  """
  @spec validate_workspace_reference(nil | :ok | {:error, atom()}) ::
          :ok | {:error, atom()}
  def validate_workspace_reference(nil), do: :ok
  def validate_workspace_reference(:ok), do: :ok
  def validate_workspace_reference({:error, reason}), do: {:error, reason}

  @doc """
  Composes user and workspace validation. Returns `:ok` if both pass,
  or the first error encountered.
  """
  @spec validate_references(boolean() | {:error, term()}, nil | :ok | {:error, atom()}) ::
          :ok | {:error, atom()}
  def validate_references(user_result, workspace_result) do
    with :ok <- validate_user_reference(user_result),
         :ok <- validate_workspace_reference(workspace_result) do
      :ok
    end
  end
end

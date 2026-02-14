defmodule EntityRelationshipManager.Domain.Policies.TraversalPolicy do
  @moduledoc """
  Domain policy for validating graph traversal parameters.

  Pure functions that validate depth, direction, limit, and offset
  parameters for graph traversal operations.

  NO I/O, NO database, NO side effects.
  """

  @min_depth 1
  @max_depth 10
  @min_limit 1
  @max_limit 500
  @valid_directions ["in", "out", "both"]

  @doc """
  Validates a traversal depth value.

  Valid depths are integers from #{@min_depth} to #{@max_depth}.
  """
  @spec validate_depth(term()) :: :ok | {:error, String.t()}
  def validate_depth(depth)
      when is_integer(depth) and depth >= @min_depth and depth <= @max_depth do
    :ok
  end

  def validate_depth(depth) when is_integer(depth) do
    {:error, "depth must be between #{@min_depth} and #{@max_depth}, got: #{depth}"}
  end

  def validate_depth(_depth) do
    {:error, "depth must be an integer between #{@min_depth} and #{@max_depth}"}
  end

  @doc """
  Validates a traversal direction value.

  Valid directions are: #{Enum.join(@valid_directions, ", ")}.
  """
  @spec validate_direction(term()) :: :ok | {:error, String.t()}
  def validate_direction(direction) when direction in @valid_directions do
    :ok
  end

  def validate_direction(_direction) do
    {:error, "direction must be one of: #{Enum.join(@valid_directions, ", ")}"}
  end

  @doc """
  Validates a traversal limit value.

  Valid limits are integers from #{@min_limit} to #{@max_limit}.
  """
  @spec validate_limit(term()) :: :ok | {:error, String.t()}
  def validate_limit(limit)
      when is_integer(limit) and limit >= @min_limit and limit <= @max_limit do
    :ok
  end

  def validate_limit(limit) when is_integer(limit) do
    {:error, "limit must be between #{@min_limit} and #{@max_limit}, got: #{limit}"}
  end

  def validate_limit(_limit) do
    {:error, "limit must be an integer between #{@min_limit} and #{@max_limit}"}
  end

  @doc """
  Validates a traversal offset value.

  Valid offsets are non-negative integers.
  """
  @spec validate_offset(term()) :: :ok | {:error, String.t()}
  def validate_offset(offset) when is_integer(offset) and offset >= 0 do
    :ok
  end

  def validate_offset(offset) when is_integer(offset) do
    {:error, "offset must be a non-negative integer, got: #{offset}"}
  end

  def validate_offset(_offset) do
    {:error, "offset must be a non-negative integer"}
  end

  @doc """
  Returns the default traversal depth.
  """
  @spec default_depth() :: pos_integer()
  def default_depth, do: @min_depth

  @doc """
  Returns the maximum allowed traversal depth.
  """
  @spec max_depth() :: pos_integer()
  def max_depth, do: @max_depth
end

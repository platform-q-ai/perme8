defmodule EntityRelationshipManager.ControllerHelpers do
  @moduledoc """
  Shared helper functions for ERM controllers.

  Provides common parameter parsing and error handling utilities
  to avoid duplication across controllers.
  """

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Adds a string value to the map if it's not nil.
  """
  def maybe_put(map, _key, nil), do: {:ok, map}
  def maybe_put(map, key, value), do: {:ok, Map.put(map, key, value)}

  @doc """
  Parses and adds an integer value to the map.

  Returns `{:ok, map}` on success or `{:error, field}` if the value
  is not a valid integer string.
  """
  def maybe_put_int(map, _key, nil), do: {:ok, map}

  def maybe_put_int(map, key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, Map.put(map, key, int)}
      _ -> {:error, key}
    end
  end

  def maybe_put_int(map, key, value) when is_integer(value) do
    {:ok, Map.put(map, key, value)}
  end

  @doc """
  Adds a keyword opt if the value is not nil.
  """
  def maybe_put_opt(opts, _key, nil), do: {:ok, opts}
  def maybe_put_opt(opts, key, value), do: {:ok, Keyword.put(opts, key, value)}

  @doc """
  Parses and adds an integer keyword opt.

  Returns `{:ok, opts}` on success or `{:error, field}` if the value
  is not a valid integer string.
  """
  def maybe_put_int_opt(opts, _key, nil), do: {:ok, opts}

  def maybe_put_int_opt(opts, key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, Keyword.put(opts, key, int)}
      _ -> {:error, key}
    end
  end

  def maybe_put_int_opt(opts, key, value) when is_integer(value) do
    {:ok, Keyword.put(opts, key, value)}
  end

  @doc """
  Builds a map of filters from query params, validating integer fields.

  Returns `{:ok, filters}` or sends a 400 response and returns `{:error, conn}`.
  """
  def build_filters(conn, params, fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {key, type, param_name}, {:ok, acc} ->
      value = params[param_name]

      result =
        case type do
          :string -> maybe_put(acc, key, value)
          :integer -> maybe_put_int(acc, key, value)
        end

      case result do
        {:ok, new_acc} ->
          {:cont, {:ok, new_acc}}

        {:error, field} ->
          error_conn =
            conn
            |> put_status(:bad_request)
            |> json(%{error: "bad_request", message: "Invalid integer value for '#{field}'"})
            |> halt()

          {:halt, {:error, error_conn}}
      end
    end)
  end

  @doc """
  Builds a keyword list of opts from query params, validating integer fields.

  Returns `{:ok, opts}` or sends a 400 response and returns `{:error, conn}`.
  """
  def build_opts(conn, params, fields) do
    Enum.reduce_while(fields, {:ok, []}, fn {key, type, param_name}, {:ok, acc} ->
      value = params[param_name]

      result =
        case type do
          :string -> maybe_put_opt(acc, key, value)
          :integer -> maybe_put_int_opt(acc, key, value)
        end

      case result do
        {:ok, new_acc} ->
          {:cont, {:ok, new_acc}}

        {:error, field} ->
          error_conn =
            conn
            |> put_status(:bad_request)
            |> json(%{error: "bad_request", message: "Invalid integer value for '#{field}'"})
            |> halt()

          {:halt, {:error, error_conn}}
      end
    end)
  end

  @doc """
  Standard error handling for ERM controllers.
  """
  def handle_common_error(conn, :schema_not_found) do
    conn
    |> put_status(:not_found)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> Phoenix.Controller.render("404.json")
  end

  def handle_common_error(conn, {:validation_errors, errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_errors", errors: errors})
  end

  def handle_common_error(conn, :empty_batch) do
    conn
    |> put_status(:bad_request)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> Phoenix.Controller.render("400.json")
  end

  def handle_common_error(conn, :batch_too_large) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "Batch size exceeds maximum of 1000"})
  end

  def handle_common_error(conn, _reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EntityRelationshipManager.Views.ErrorJSON)
    |> Phoenix.Controller.render("422.json")
  end
end

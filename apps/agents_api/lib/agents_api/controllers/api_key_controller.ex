defmodule AgentsApi.ApiKeyController do
  @moduledoc """
  Controller for API key management endpoints.
  """

  use AgentsApi, :controller

  @allowed_fields ~w(name description workspace_access permissions)a

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = permitted_attrs(api_key_params(params))

    case Identity.create_api_key(user.id, attrs) do
      {:ok, {api_key, plain_token}} ->
        conn
        |> put_status(:created)
        |> render(:created, api_key: api_key, token: plain_token)

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> render(:error, message: "Forbidden")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)
    end
  end

  def update(conn, %{"id" => api_key_id} = params) do
    user = conn.assigns.current_user
    attrs = permitted_attrs(api_key_params(params))

    case Identity.update_api_key(user.id, api_key_id, attrs) do
      {:ok, api_key} ->
        render(conn, :show, api_key: api_key)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "API key not found")

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> render(:error, message: "Forbidden")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:validation_error, changeset: changeset)
    end
  end

  defp permitted_attrs(params) do
    Enum.reduce(@allowed_fields, %{}, fn field, acc ->
      string_key = Atom.to_string(field)

      cond do
        Map.has_key?(params, string_key) ->
          Map.put(acc, field, Map.get(params, string_key))

        Map.has_key?(params, field) ->
          Map.put(acc, field, Map.get(params, field))

        true ->
          acc
      end
    end)
  end

  defp api_key_params(params) do
    Map.get(params, "api_key") || Map.get(params, :api_key) || params
  end
end

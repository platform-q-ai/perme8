defmodule AgentsApi.ApiKeyJSON do
  @moduledoc """
  JSON rendering for API key endpoints.
  """

  def created(%{api_key: api_key, token: token}) do
    %{data: api_key_data(api_key), token: token}
  end

  def show(%{api_key: api_key}) do
    %{data: api_key_data(api_key)}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  def validation_error(%{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  defp api_key_data(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      description: api_key.description,
      permissions: api_key.permissions,
      workspace_access: api_key.workspace_access,
      is_active: api_key.is_active,
      inserted_at: api_key.inserted_at,
      updated_at: api_key.updated_at
    }
  end
end

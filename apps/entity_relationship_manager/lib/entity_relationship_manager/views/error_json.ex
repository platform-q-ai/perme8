defmodule EntityRelationshipManager.Views.ErrorJSON do
  @moduledoc """
  Standard error JSON responses for the Entity Relationship Manager API.

  Uses the `%{errors: %{detail: message}}` envelope format to align
  with JargaApi.ErrorJSON.
  """

  def render("400.json", _assigns) do
    %{errors: %{detail: "Bad request"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Authentication required"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "You do not have permission to perform this action"}}
  end

  def render("404.json", _assigns) do
    %{errors: %{detail: "Resource not found"}}
  end

  def render("422.json", %{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  def render("422.json", _assigns) do
    %{errors: %{detail: "Unprocessable entity"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal server error"}}
  end

  def render("503.json", _assigns) do
    %{errors: %{detail: "Graph database is temporarily unavailable"}}
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

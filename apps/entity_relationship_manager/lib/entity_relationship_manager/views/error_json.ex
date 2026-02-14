defmodule EntityRelationshipManager.Views.ErrorJSON do
  @moduledoc """
  Standard error JSON responses for the Entity Relationship Manager API.

  Uses the `%{error: "type", message: "details"}` envelope format for consistency
  with the auth plugs and BDD feature expectations.
  """

  def render("400.json", %{message: message}) do
    %{error: "bad_request", message: message}
  end

  def render("400.json", _assigns) do
    %{error: "bad_request", message: "Bad request"}
  end

  def render("401.json", _assigns) do
    %{error: "unauthorized", message: "Authentication required"}
  end

  def render("403.json", _assigns) do
    %{error: "forbidden", message: "You do not have permission to perform this action"}
  end

  def render("404.json", _assigns) do
    %{error: "not_found", message: "Resource not found"}
  end

  def render("409.json", _assigns) do
    %{
      error: "version_conflict",
      message: "Schema has been modified by a concurrent update; please reload and retry"
    }
  end

  def render("422.json", %{changeset: changeset}) do
    %{error: "validation_error", errors: translate_errors(changeset)}
  end

  def render("422.json", %{message: message}) do
    %{error: "unprocessable_entity", message: message}
  end

  def render("422.json", _assigns) do
    %{error: "unprocessable_entity", message: "Unprocessable entity"}
  end

  def render("500.json", _assigns) do
    %{error: "internal_server_error", message: "Internal server error"}
  end

  def render("503.json", _assigns) do
    %{error: "graph_unavailable", message: "Graph database is temporarily unavailable"}
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

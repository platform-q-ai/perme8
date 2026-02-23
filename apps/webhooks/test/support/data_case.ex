defmodule Webhooks.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the WebhooksApi database layer.

  Uses the Ecto SQL Sandbox so changes are reverted
  at the end of every test.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias WebhooksApi.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Webhooks.DataCase
    end
  end

  setup tags do
    Webhooks.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.

  Checks out WebhooksApi.Repo (and Identity.Repo / Jarga.Repo for
  cross-context queries when needed).
  """
  def setup_sandbox(tags) do
    :ok = Sandbox.checkout(WebhooksApi.Repo)

    unless tags[:async] do
      Sandbox.mode(WebhooksApi.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(WebhooksApi.Repo)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = create_something(%{field: "bad"})
      assert "is invalid" in errors_on(changeset).field
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

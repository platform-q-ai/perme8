defmodule Chat.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Chat.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Chat.DataCase
    end
  end

  setup tags do
    Chat.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    :ok = Sandbox.checkout(Chat.Repo)
    :ok = Sandbox.checkout(Identity.Repo)

    Sandbox.allow(Chat.Repo, self(), self())
    Sandbox.allow(Identity.Repo, self(), self())

    unless tags[:async] do
      Sandbox.mode(Chat.Repo, {:shared, self()})
      Sandbox.mode(Identity.Repo, {:shared, self()})
    end
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

defmodule Jarga.Repo do
  # Shared infrastructure - can be used by all contexts
  # Cannot depend on contexts or web layer
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :jarga,
    adapter: Ecto.Adapters.Postgres

  if Mix.env() == :test do
    # In test mode, Jarga.Repo delegates all queries to Identity.Repo.
    # Both repos share the same PostgreSQL database. This ensures data inserted
    # via Identity.Repo (users, workspaces) is visible to Jarga.Repo queries
    # within the same Ecto sandbox transaction — including spawned processes
    # like LiveView channels. Without this, FK constraints fail because each
    # repo's sandbox runs in a separate DB connection.
    #
    # Falls back to Jarga.Repo itself when a process has explicitly set a
    # dynamic repo via put_dynamic_repo, or when Identity.Repo isn't available
    # (e.g., during migrations).
    defoverridable get_dynamic_repo: 0

    def get_dynamic_repo do
      case Process.get({__MODULE__, :dynamic_repo}) do
        nil ->
          if GenServer.whereis(Identity.Repo) do
            Identity.Repo
          else
            __MODULE__
          end

        repo ->
          repo
      end
    end
  end

  if Mix.env() == :test do
    @doc false
    # In test mode, Jarga.Repo delegates all queries to Identity.Repo.
    # Both repos share the same PostgreSQL database. This ensures data inserted
    # via Identity.Repo (users, workspaces) is visible to Jarga.Repo queries
    # within the same Ecto sandbox transaction — including spawned processes
    # like LiveView channels. Without this, FK constraints fail because each
    # repo's sandbox runs in a separate DB connection.
    #
    # Falls back to Jarga.Repo itself when Identity.Repo isn't started yet
    # (e.g., during migrations).
    def get_dynamic_repo do
      case Process.get({__MODULE__, :dynamic_repo}) do
        nil ->
          if Process.whereis(Identity.Repo) do
            Identity.Repo
          else
            __MODULE__
          end

        repo ->
          repo
      end
    end
  end

  @doc """
  Executes a function inside a transaction and unwraps the result.

  If the function returns `{:ok, value}` or `{:error, reason}`, returns that directly.
  Otherwise wraps the result in `{:ok, result}`.

  This is a convenience wrapper to avoid double-wrapping of results.

  Note: Cannot be named `transact/1` due to conflict with Ecto.Repo's `transact/2`.

  ## Examples

      iex> Repo.unwrap_transaction(fn -> {:ok, "result"} end)
      {:ok, "result"}
      
      iex> Repo.unwrap_transaction(fn -> {:error, :reason} end)
      {:error, :reason}
  """
  def unwrap_transaction(transaction_fun) when is_function(transaction_fun, 0) do
    case transaction(transaction_fun) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end

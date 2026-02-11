defmodule Identity.Repo do
  @moduledoc """
  Ecto repository for the Identity app.

  Connects to the same database as Jarga.Repo but allows Identity
  to be self-contained without depending on the jarga app.
  """

  # Shared infrastructure - can be used by all Identity modules
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :identity,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Executes a function inside a transaction and unwraps the result.

  If the function returns `{:ok, value}` or `{:error, reason}`, returns that directly.
  Otherwise wraps the result in `{:ok, result}`.

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

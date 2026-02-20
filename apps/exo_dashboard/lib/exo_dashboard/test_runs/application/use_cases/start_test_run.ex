defmodule ExoDashboard.TestRuns.Application.UseCases.StartTestRun do
  @moduledoc """
  Use case for starting a new test run.

  Creates a TestRun entity, stores it, spawns the executor,
  and broadcasts a start event via PubSub.
  """

  alias ExoDashboard.TestRuns.Domain.Entities.TestRun

  @doc """
  Starts a new test run with the given scope.

  Accepts opts with:
  - `:scope` -- {:app, app_name} | {:feature, uri} | {:scenario, uri, line}
  - `:store` / `:store_mod` -- store process and module (dependency injection)
  - `:executor_mod` -- executor module (stateless, no process needed)
  - `:pubsub` / `:pubsub_mod` -- PubSub process and module

  Returns `{:ok, run_id}`.
  """
  @spec execute(keyword()) :: {:ok, String.t()}
  def execute(opts) do
    scope = Keyword.fetch!(opts, :scope)
    store = Keyword.fetch!(opts, :store)
    store_mod = Keyword.fetch!(opts, :store_mod)
    executor_mod = Keyword.fetch!(opts, :executor_mod)
    pubsub = Keyword.fetch!(opts, :pubsub)
    pubsub_mod = Keyword.fetch!(opts, :pubsub_mod)

    run_id = generate_id()

    run =
      TestRun.new(
        id: run_id,
        scope: scope,
        status: :pending
      )

    store_mod.create_run(store, run)

    executor_mod.start(run_id, scope: scope)

    pubsub_mod.broadcast(pubsub, "exo_dashboard:runs", {:test_run_started, run_id})

    {:ok, run_id}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end

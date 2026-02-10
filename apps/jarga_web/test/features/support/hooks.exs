defmodule CucumberHooks do
  @moduledoc """
  Hooks for Cucumber tests to handle database sandbox and test setup.

  IMPORTANT: This module provides hooks that run AFTER ExUnit setup callbacks.
  For tests with Background sections, the Background steps run in setup BEFORE
  these hooks. To ensure database access for Background steps, we need to checkout
  the sandbox earlier.

  The solution is to have Background steps themselves handle sandbox setup if needed,
  or ensure sandbox is set up in ExUnit's setup callback before Background runs.
  """

  use Cucumber.Hooks

  alias Ecto.Adapters.SQL.Sandbox

  # Global before hook - runs for all scenarios AFTER ExUnit setup
  # This runs AFTER Background steps, so Background steps need their own sandbox setup
  before_scenario context do
    # Check if sandbox is already checked out (from Background setup)
    # If not, check it out now for both repos
    for repo <- [Jarga.Repo, Identity.Repo] do
      case Sandbox.checkout(repo) do
        :ok ->
          # Always use shared mode for Cucumber tests
          Sandbox.mode(repo, {:shared, self()})

        {:already, _owner} ->
          :ok
      end
    end

    {:ok, context}
  end

  # After each scenario - cleanup
  after_scenario context do
    # Unsubscribe from any PubSub topics
    if subscriptions = Map.get(context, :pubsub_subscriptions) do
      Enum.each(subscriptions, fn {_email, topic} ->
        Phoenix.PubSub.unsubscribe(Jarga.PubSub, topic)
      end)
    end

    :ok
  end
end

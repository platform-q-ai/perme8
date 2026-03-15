defmodule Agents.Sessions.Infrastructure.Adapters.NoopContainerProvider do
  @moduledoc """
  No-op container provider for test environments where Docker is unavailable.

  Returns success for all operations without performing any actual container
  management. Used as the default container_provider in config/test.exs so
  that LiveView integration tests (which go through the full stack without
  injecting a mock) don't crash on Docker binary absence.
  """

  @behaviour Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour

  @impl true
  def start(_image, _opts \\ []) do
    {:ok, %{container_id: "noop-#{System.unique_integer([:positive])}", port: 4096}}
  end

  @impl true
  def stop(_container_id, _opts \\ []), do: :ok

  @impl true
  def remove(_container_id, _opts \\ []), do: :ok

  @impl true
  def restart(_container_id, _opts \\ []) do
    {:ok, %{port: 4096}}
  end

  @impl true
  def status(_container_id, _opts \\ []) do
    {:ok, :not_found}
  end

  @impl true
  def stats(_container_id, _opts \\ []) do
    {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}
  end

  @impl true
  def prepare_fresh_start(_container_id, _opts \\ []), do: :ok
end

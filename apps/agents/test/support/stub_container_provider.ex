defmodule Agents.Test.StubContainerProvider do
  @moduledoc """
  A test stub for ContainerProviderBehaviour that delegates to functions
  stored in a named ETS table. Use `new/1` to create a module with
  the desired function implementations.

  ## Usage

      provider = Agents.Test.StubContainerProvider.new(%{
        start: fn _image, _opts -> {:ok, %{container_id: "cid", port: 4000}} end,
        stop: fn _id -> :ok end,
        status: fn _id -> {:ok, :running} end
      })

      start_orchestrator!(user.id, container_provider: provider)
  """

  @doc """
  Creates a new StubContainerProvider backed by a uniquely named ETS table.
  Returns a dynamically defined module that the QueueOrchestrator can call.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def new(fns) when is_map(fns) do
    table_name = :"stub_container_#{System.unique_integer([:positive, :monotonic])}"
    :ets.new(table_name, [:named_table, :public, :set])
    :ets.insert(table_name, {:fns, fns})

    mod_name = :"Agents.Test.StubContainerProvider.I#{System.unique_integer([:positive])}"

    contents =
      quote do
        @table_name unquote(table_name)

        defp get_fn(key) do
          case :ets.lookup(@table_name, :fns) do
            [{:fns, fns}] -> Map.get(fns, key)
            _ -> nil
          end
        end

        def start(image, opts) do
          case get_fn(:start) do
            fun when is_function(fun, 2) -> fun.(image, opts)
            _ -> {:ok, %{container_id: "stub-#{System.unique_integer([:positive])}", port: 4000}}
          end
        end

        def stop(container_id) do
          case get_fn(:stop) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> :ok
          end
        end

        def remove(container_id) do
          case get_fn(:remove) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> :ok
          end
        end

        def restart(container_id) do
          case get_fn(:restart) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> {:ok, %{port: 4000}}
          end
        end

        def status(container_id) do
          case get_fn(:status) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> {:ok, :running}
          end
        end

        def stats(container_id) do
          case get_fn(:stats) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}
          end
        end

        def prepare_fresh_start(container_id) do
          case get_fn(:prepare_fresh_start) do
            fun when is_function(fun, 1) -> fun.(container_id)
            _ -> :ok
          end
        end
      end

    {:module, mod, _, _} = Module.create(mod_name, contents, Macro.Env.location(__ENV__))
    mod
  end
end

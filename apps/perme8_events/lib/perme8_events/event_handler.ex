defmodule Perme8.Events.EventHandler do
  @moduledoc """
  Behaviour and macro for building event handler GenServers.

  Handlers auto-subscribe to topics on startup and route incoming
  structured events to `handle_event/1`.

  ## Usage

      defmodule MyApp.Handlers.ProjectHandler do
        use Perme8.Events.EventHandler

        @impl true
        def subscriptions do
          ["events:projects", "events:projects:project"]
        end

        @impl true
        def handle_event(%ProjectCreated{} = event) do
          # React to project creation
          :ok
        end

        @impl true
        def handle_event(_event), do: :ok
      end
  """

  @doc "Handle a domain event struct. Return :ok or {:error, reason}."
  @callback handle_event(event :: struct()) :: :ok | {:error, term()}

  @doc "List of PubSub topics to subscribe to on startup."
  @callback subscriptions() :: [String.t()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Perme8.Events.EventHandler

      use GenServer

      require Logger

      def start_link(opts) do
        name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, name: name)
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent
        }
      end

      @impl GenServer
      def init(opts) do
        # Runtime lookup: this runs inside a quote block (macro-expanded into consumer
        # modules), so compile_env would capture the value at the wrong compile context.
        pubsub = Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub)

        subscriptions()
        |> Enum.each(fn topic ->
          Phoenix.PubSub.subscribe(pubsub, topic)
        end)

        {:ok, %{opts: opts}}
      end

      @impl GenServer
      def handle_info(%{__struct__: _} = event, state) do
        # Binding through identity/1 prevents the type checker from narrowing
        # the return type of handle_event/1 into the case clauses, which would
        # cause unreachable-clause warnings in handlers that only return :ok
        # or only return {:error, _}.
        #
        # The try/rescue wraps the entire handler invocation so that a sandbox
        # or connection error (e.g. owner process exited during tests) never
        # crashes the GenServer. With one_for_one supervision and default
        # max_restarts: 3, repeated crashes would kill the entire supervisor
        # — including Repo — causing mass "could not lookup Ecto repo" failures.
        try do
          case Function.identity(handle_event(event)) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error(
                "[#{inspect(__MODULE__)}] Error handling event #{inspect(event.__struct__)}: #{inspect(reason)}"
              )
          end
        rescue
          e ->
            Logger.warning(
              "[#{inspect(__MODULE__)}] Event handler rescued from #{inspect(e.__struct__)}: #{Exception.message(e)}"
            )
        end

        {:noreply, state}
      end

      @impl GenServer
      def handle_info(message, state) do
        Logger.debug(
          "[#{inspect(__MODULE__)}] Received unexpected non-struct message: #{inspect(message)}"
        )

        {:noreply, state}
      end

      defoverridable child_spec: 1, start_link: 1
    end
  end
end

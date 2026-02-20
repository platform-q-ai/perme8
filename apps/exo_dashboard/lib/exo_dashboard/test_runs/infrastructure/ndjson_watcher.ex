defmodule ExoDashboard.TestRuns.Infrastructure.NdjsonWatcher do
  @moduledoc """
  GenServer that polls an NDJSON file for new lines.

  Tracks the byte offset for incremental reads and parses
  each line as JSON, invoking a callback for each parsed envelope.
  Stops itself after receiving a `testRunFinished` envelope.
  """
  use GenServer

  require Logger

  @default_poll_interval 100

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    callback = Keyword.fetch!(opts, :callback)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    file_system = Keyword.get(opts, :file_system, File)

    state = %{
      path: path,
      callback: callback,
      poll_interval: poll_interval,
      file_system: file_system,
      offset: 0,
      finished: false,
      buffer: ""
    }

    schedule_poll(poll_interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:poll, %{finished: true} = state) do
    {:stop, :normal, state}
  end

  def handle_info(:poll, state) do
    state = read_new_lines(state)

    if state.finished do
      {:stop, :normal, state}
    else
      schedule_poll(state.poll_interval)
      {:noreply, state}
    end
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp read_new_lines(state) do
    fs = state.file_system

    case fs.stat(state.path) do
      {:ok, %{size: size}} when size > state.offset ->
        case fs.open(state.path, [:read, :binary]) do
          {:ok, file} ->
            :file.position(file, state.offset)
            data = IO.binread(file, size - state.offset)
            fs.close(file)

            process_data(state, data, size)

          {:error, _reason} ->
            state
        end

      _ ->
        state
    end
  end

  defp process_data(state, data, new_offset) when is_binary(data) do
    full_data = state.buffer <> data

    case String.split(full_data, "\n") do
      [] ->
        %{state | offset: new_offset}

      parts ->
        {lines, [remainder]} = Enum.split(parts, -1)
        lines = Enum.reject(lines, &(&1 == ""))

        finished =
          Enum.reduce(lines, state.finished, fn line, finished ->
            process_line(line, state.callback, finished)
          end)

        %{state | offset: new_offset, finished: finished, buffer: remainder}
    end
  end

  defp process_data(state, _data, _new_offset), do: state

  defp process_line(line, callback, finished) do
    case Jason.decode(line) do
      {:ok, envelope} ->
        callback.(envelope)
        finished || Map.has_key?(envelope, "testRunFinished")

      {:error, _} ->
        Logger.warning("Malformed JSON in NDJSON file: #{String.slice(line, 0..100)}")
        finished
    end
  end
end

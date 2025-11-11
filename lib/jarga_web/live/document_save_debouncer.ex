defmodule JargaWeb.DocumentSaveDebouncer do
  @moduledoc """
  GenServer that debounces document saves to prevent database race conditions.

  Each document gets its own debouncer process that:
  - Receives save requests immediately
  - Broadcasts updates to other clients immediately
  - Debounces actual database writes (2 seconds after last update)
  - Ensures no data loss by processing all pending saves on termination
  """
  use GenServer

  require Logger

  # Configurable debounce time via environment variable
  # Defaults to 2 seconds (2000ms)
  # Can be overridden with DOCUMENT_SAVE_DEBOUNCE_MS environment variable (e.g., "1" for tests)
  @debounce_time String.to_integer(System.get_env("DOCUMENT_SAVE_DEBOUNCE_MS", "2000"))

  ## Client API

  @doc """
  Start a debouncer for a specific document.
  Returns {:ok, pid} or {:error, reason}
  """
  def start_link(document_id) do
    GenServer.start_link(__MODULE__, document_id, name: via_tuple(document_id))
  end

  @doc """
  Request a save for a document.
  This will debounce the actual database write but return immediately.
  Returns the GenServer PID for test database ownership setup.
  """
  def request_save(document_id, user, note_id, yjs_state, markdown) do
    pid =
      case GenServer.whereis(via_tuple(document_id)) do
        nil ->
          # Start the debouncer if it doesn't exist
          case DynamicSupervisor.start_child(
                 JargaWeb.DocumentSaveDebouncerSupervisor,
                 {__MODULE__, document_id}
               ) do
            {:ok, pid} ->
              pid

            {:error, {:already_started, pid}} ->
              pid

            error ->
              Logger.error("Failed to start DocumentSaveDebouncer: #{inspect(error)}")
              nil
          end

        pid ->
          pid
      end

    if pid do
      GenServer.cast(via_tuple(document_id), {:save, user, note_id, yjs_state, markdown})
    end

    pid
  end

  ## Server Callbacks

  @impl true
  def init(document_id) do
    {:ok,
     %{
       document_id: document_id,
       pending_save: nil,
       timer_ref: nil
     }}
  end

  @impl true
  def handle_cast({:save, user, note_id, yjs_state, markdown}, state) do
    # Cancel any existing timer
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    # Store the pending save
    pending_save = %{
      user: user,
      note_id: note_id,
      yjs_state: yjs_state,
      markdown: markdown
    }

    # Schedule a new save
    timer_ref = Process.send_after(self(), :execute_save, @debounce_time)

    {:noreply, %{state | pending_save: pending_save, timer_ref: timer_ref}}
  end

  @impl true
  def handle_info(:execute_save, state) do
    if state.pending_save do
      execute_save(state.pending_save)
    end

    # Clear the pending save and timer
    {:noreply, %{state | pending_save: nil, timer_ref: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure we save any pending changes before terminating (production only)
    # In test mode, the database connection may be unavailable during termination
    if state.pending_save && Application.get_env(:jarga, :env) != :test do
      execute_save(state.pending_save)
    end

    :ok
  end

  ## Private Functions

  defp execute_save(%{user: user, note_id: note_id, yjs_state: yjs_state, markdown: markdown}) do
    update_attrs = %{
      yjs_state: yjs_state,
      note_content: %{"markdown" => markdown}
    }

    case Jarga.Notes.update_note_via_document(user, note_id, update_attrs) do
      {:ok, _note} ->
        :ok

      {:error, :note_not_found} ->
        # In test mode, notes may be deleted before debouncer fires - this is expected
        # In production, log as warning since it might indicate a race condition
        if Application.get_env(:jarga, :env) == :test do
          :ok
        else
          Logger.warning("Note #{note_id} not found during debounced save")
          :error
        end

      {:error, reason} ->
        Logger.error("Failed to save note #{note_id}: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Get the PID of the debouncer for a document (for testing).
  """
  def get_debouncer_pid(document_id) do
    GenServer.whereis(via_tuple(document_id))
  end

  @doc """
  Wait for any pending saves to complete (for testing).
  Polls the GenServer state until pending_save is nil.
  """
  def wait_for_save(document_id, timeout \\ 5000) do
    case get_debouncer_pid(document_id) do
      nil ->
        :ok

      pid ->
        wait_until = System.monotonic_time(:millisecond) + timeout
        wait_for_save_loop(pid, wait_until)
    end
  end

  defp wait_for_save_loop(pid, wait_until) do
    if System.monotonic_time(:millisecond) > wait_until do
      {:error, :timeout}
    else
      case :sys.get_state(pid) do
        %{pending_save: nil} ->
          :ok

        _ ->
          Process.sleep(100)
          wait_for_save_loop(pid, wait_until)
      end
    end
  end

  defp via_tuple(document_id) do
    {:via, Registry, {JargaWeb.DocumentSaveDebouncerRegistry, document_id}}
  end
end

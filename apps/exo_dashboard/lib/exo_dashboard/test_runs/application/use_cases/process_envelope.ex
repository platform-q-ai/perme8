defmodule ExoDashboard.TestRuns.Application.UseCases.ProcessEnvelope do
  @moduledoc """
  Use case for processing a single Cucumber Message envelope.

  Pattern matches on the envelope type and delegates to the
  appropriate store operations for state management.
  """

  alias ExoDashboard.TestRuns.Domain.Entities.TestRun
  alias ExoDashboard.TestRuns.Domain.Policies.StatusPolicy

  @doc """
  Processes a Cucumber Message envelope for a given run.

  Accepts opts with `:store` (the store process/pid) and `:store_mod` (the module
  implementing the store behaviour) for dependency injection.
  """
  @spec execute(String.t(), map(), keyword()) :: :ok
  def execute(run_id, envelope, opts \\ []) do
    store = Keyword.fetch!(opts, :store)
    store_mod = Keyword.fetch!(opts, :store_mod)

    process_envelope(run_id, envelope, store, store_mod)
  end

  defp process_envelope(run_id, %{"testRunStarted" => _data}, store, store_mod) do
    store_mod.update_run(store, run_id, fn run -> TestRun.start(run) end)
  end

  defp process_envelope(run_id, %{"pickle" => pickle}, store, store_mod) do
    store_mod.register_pickle(store, run_id, pickle["id"], pickle)
  end

  defp process_envelope(run_id, %{"testCase" => test_case}, store, store_mod) do
    store_mod.register_test_case(store, run_id, test_case["id"], test_case["pickleId"])
  end

  defp process_envelope(run_id, %{"testCaseStarted" => data}, store, store_mod) do
    test_case_id = data["testCaseId"]
    pickle_id = store_mod.get_test_case_pickle_id(store, run_id, test_case_id)
    pickle = if pickle_id, do: store_mod.get_pickle(store, run_id, pickle_id)

    result = %{
      pickle_id: pickle_id,
      test_case_id: test_case_id,
      test_case_started_id: data["id"],
      status: :pending,
      step_results: [],
      feature_uri: pickle && pickle["uri"],
      scenario_name: pickle && pickle["name"],
      attempt: data["attempt"]
    }

    store_mod.add_test_case_result(store, run_id, data["id"], result)
  end

  defp process_envelope(run_id, %{"testStepFinished" => data}, store, store_mod) do
    test_case_started_id = data["testCaseStartedId"]
    step_result = data["testStepResult"]

    status = parse_status(step_result["status"])
    duration_ms = parse_duration_ms(step_result["duration"])

    error_message =
      case step_result do
        %{"message" => msg} -> msg
        _ -> nil
      end

    step = %{
      test_step_id: data["testStepId"],
      status: status,
      duration_ms: duration_ms,
      error_message: error_message
    }

    existing = store_mod.get_test_case_result(store, run_id, test_case_started_id)

    if existing do
      updated_steps = (existing[:step_results] || []) ++ [step]

      updated_result = %{
        existing
        | step_results: updated_steps,
          status: aggregate_step_statuses(updated_steps)
      }

      store_mod.add_test_case_result(store, run_id, test_case_started_id, updated_result)
    else
      :ok
    end
  end

  defp process_envelope(run_id, %{"testCaseFinished" => data}, store, store_mod) do
    test_case_started_id = data["testCaseStartedId"]
    existing = store_mod.get_test_case_result(store, run_id, test_case_started_id)

    if existing do
      store_mod.add_test_case_result(store, run_id, test_case_started_id, existing)
    else
      :ok
    end
  end

  defp process_envelope(run_id, %{"testRunFinished" => data}, store, store_mod) do
    success = data["success"]

    store_mod.update_run(store, run_id, fn run ->
      status = if success, do: :passed, else: :failed
      TestRun.finish(run, status)
    end)
  end

  defp process_envelope(_run_id, _envelope, _store, _store_mod) do
    # Ignore unrecognized envelope types (meta, source, gherkinDocument, etc.)
    :ok
  end

  defp parse_status("PASSED"), do: :passed
  defp parse_status("FAILED"), do: :failed
  defp parse_status("PENDING"), do: :pending
  defp parse_status("SKIPPED"), do: :skipped
  defp parse_status("UNDEFINED"), do: :undefined
  defp parse_status("AMBIGUOUS"), do: :ambiguous
  defp parse_status(_), do: :unknown

  defp parse_duration_ms(%{"seconds" => seconds, "nanos" => nanos}) do
    seconds * 1_000 + div(nanos, 1_000_000)
  end

  defp parse_duration_ms(_), do: 0

  defp aggregate_step_statuses(steps) do
    statuses = Enum.map(steps, & &1.status)
    StatusPolicy.aggregate_status(statuses)
  end
end

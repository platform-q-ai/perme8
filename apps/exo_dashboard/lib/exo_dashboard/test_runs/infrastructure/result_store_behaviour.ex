defmodule ExoDashboard.TestRuns.Infrastructure.ResultStoreBehaviour do
  @moduledoc """
  Behaviour defining the contract for test run result storage.

  Used for dependency injection in use cases, enabling
  mock implementations in tests.
  """

  @callback update_run(String.t(), function()) :: :ok
  @callback register_pickle(String.t(), String.t(), map()) :: :ok
  @callback register_test_case(String.t(), String.t(), String.t()) :: :ok
  @callback add_test_case_result(String.t(), String.t(), map()) :: :ok
  @callback get_pickle(String.t(), String.t()) :: map() | nil
  @callback get_test_case_pickle_id(String.t(), String.t()) :: String.t() | nil
  @callback get_test_case_result(String.t(), String.t()) :: map() | nil
end

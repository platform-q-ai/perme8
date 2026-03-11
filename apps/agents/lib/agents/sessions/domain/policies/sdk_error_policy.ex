defmodule Agents.Sessions.Domain.Policies.SdkErrorPolicy do
  @moduledoc """
  Classifies SDK error categories as recoverable or terminal.

  Terminal errors cause the session to transition to `failed`.
  Recoverable errors keep the session running with retry metadata.

  Unknown error categories are classified as terminal (fail-safe).
  """

  @type classification :: {:terminal | :recoverable, atom()}

  @doc "Classifies an error category string as terminal or recoverable."
  @spec classify(String.t() | nil) :: classification()
  def classify("auth"), do: {:terminal, :auth}
  def classify("abort"), do: {:terminal, :abort}
  def classify("api"), do: {:recoverable, :api}
  def classify("output_length"), do: {:recoverable, :output_length}
  def classify("rate_limit"), do: {:recoverable, :rate_limit}
  def classify(_), do: {:terminal, :unknown}

  @doc "Returns true if the error category is terminal."
  @spec terminal?(String.t() | nil) :: boolean()
  def terminal?(category) do
    {type, _} = classify(category)
    type == :terminal
  end

  @doc "Returns true if the error category is recoverable."
  @spec recoverable?(String.t() | nil) :: boolean()
  def recoverable?(category) do
    {type, _} = classify(category)
    type == :recoverable
  end
end

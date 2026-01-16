defmodule Jarga.Projects.Application.UseCases.UseCase do
  @moduledoc """
  Behavior for use cases in the application layer.

  Use cases encapsulate business operations and orchestrate domain logic,
  infrastructure services, and side effects (notifications, events).
  """

  @doc """
  Executes the use case with the given parameters.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @callback execute(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
end

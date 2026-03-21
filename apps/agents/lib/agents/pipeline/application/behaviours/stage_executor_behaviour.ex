defmodule Agents.Pipeline.Application.Behaviours.StageExecutorBehaviour do
  @moduledoc false

  alias Agents.Pipeline.Domain.Entities.Stage

  @callback execute(Stage.t(), map()) ::
              {:ok, %{output: String.t(), exit_code: integer() | nil, metadata: map()}}
              | {:error,
                 %{
                   output: String.t(),
                   exit_code: integer() | nil,
                   reason: term(),
                   metadata: map()
                 }}
end

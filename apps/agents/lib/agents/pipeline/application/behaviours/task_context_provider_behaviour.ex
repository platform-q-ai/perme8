defmodule Agents.Pipeline.Application.Behaviours.TaskContextProviderBehaviour do
  @moduledoc false

  @callback get_task_context(Ecto.UUID.t()) ::
              {:ok,
               %{
                 user_id: String.t() | nil,
                 container_id: String.t() | nil,
                 instruction: String.t() | nil
               }}
              | {:error, term()}
end

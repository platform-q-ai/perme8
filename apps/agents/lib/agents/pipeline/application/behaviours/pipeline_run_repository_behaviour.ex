defmodule Agents.Pipeline.Application.Behaviours.PipelineRunRepositoryBehaviour do
  @moduledoc false

  @type persisted_run :: map()

  @callback create_run(map(), module()) :: {:ok, persisted_run()} | {:error, Ecto.Changeset.t()}
  @callback get_run(Ecto.UUID.t(), module()) :: {:ok, persisted_run()} | {:error, :not_found}
  @callback list_runs_for_pull_request(integer(), module()) :: [persisted_run()]
  @callback update_run(Ecto.UUID.t(), map(), module()) ::
              {:ok, persisted_run()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
end

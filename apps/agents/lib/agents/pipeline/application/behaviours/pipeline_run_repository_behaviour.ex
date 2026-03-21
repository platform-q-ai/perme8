defmodule Agents.Pipeline.Application.Behaviours.PipelineRunRepositoryBehaviour do
  @moduledoc false

  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema

  @callback create_run(map(), module()) ::
              {:ok, PipelineRunSchema.t()} | {:error, Ecto.Changeset.t()}
  @callback get_run(Ecto.UUID.t(), module()) ::
              {:ok, PipelineRunSchema.t()} | {:error, :not_found}
  @callback update_run(Ecto.UUID.t(), map(), module()) ::
              {:ok, PipelineRunSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
end

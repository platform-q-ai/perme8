defmodule Agents.Pipeline.Domain.Entities.PipelineConfig do
  @moduledoc """
  Pure domain entity representing the fully parsed pipeline configuration.

  This is the top-level entity returned by the LoadPipeline use case. It exposes
  the full pipeline definition — stages, deploy targets, session config, and all
  supporting configuration sections. No infrastructure dependencies.
  """

  alias Agents.Pipeline.Domain.Entities.{Stage, DeployTarget}

  @ci_trigger_events ["on_session_complete", "on_pull_request", "on_merge"]

  @type t :: %__MODULE__{
          version: integer(),
          env: map(),
          toolchain: map(),
          services: map(),
          change_detection: map(),
          app_surface_map: map(),
          exo_bdd_matrix: map(),
          js_apps: map(),
          cache: map(),
          images: map(),
          sessions: map(),
          pull_requests: map(),
          stages: [Stage.t()],
          deploy_targets: [DeployTarget.t()],
          merge_queue: map()
        }

  defstruct version: 1,
            env: %{},
            toolchain: %{},
            services: %{},
            change_detection: %{},
            app_surface_map: %{},
            exo_bdd_matrix: %{},
            js_apps: %{},
            cache: %{},
            images: %{},
            sessions: %{},
            pull_requests: %{},
            stages: [],
            deploy_targets: [],
            merge_queue: %{}

  @doc "Creates a new PipelineConfig from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Returns the list of stage names in order."
  @spec stage_names(t()) :: [String.t()]
  def stage_names(%__MODULE__{stages: stages}) do
    Enum.map(stages, & &1.name)
  end

  @doc "Returns a stage by name, or nil if not found."
  @spec get_stage(t(), String.t()) :: Stage.t() | nil
  def get_stage(%__MODULE__{stages: stages}, name) do
    Enum.find(stages, &(&1.name == name))
  end

  @doc "Returns the warm-pool stage, or nil if not defined."
  @spec warm_pool_stage(t()) :: Stage.t() | nil
  def warm_pool_stage(%__MODULE__{stages: stages}) do
    Enum.find(stages, &Stage.warm_pool_stage?/1)
  end

  @doc "Returns the list of deploy target names."
  @spec deploy_target_names(t()) :: [String.t()]
  def deploy_target_names(%__MODULE__{deploy_targets: targets}) do
    Enum.map(targets, & &1.name)
  end

  @doc "Returns the sessions configuration map."
  @spec session_config(t()) :: map()
  def session_config(%__MODULE__{sessions: sessions}), do: sessions

  @doc "Returns the environment variables map."
  @spec environment_variables(t()) :: map()
  def environment_variables(%__MODULE__{env: env}), do: env

  @doc "Returns the total number of stages."
  @spec stage_count(t()) :: non_neg_integer()
  def stage_count(%__MODULE__{stages: stages}), do: length(stages)

  @doc """
  Returns only CI stages — those triggered by `on_session_complete`,
  `on_pull_request`, or `on_merge`.
  """
  @spec ci_stages(t()) :: [Stage.t()]
  def ci_stages(%__MODULE__{stages: stages}) do
    Enum.filter(stages, fn stage ->
      Enum.any?(@ci_trigger_events, &Stage.triggered_by?(stage, &1))
    end)
  end
end

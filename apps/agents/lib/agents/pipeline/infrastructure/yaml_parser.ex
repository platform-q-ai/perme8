defmodule Agents.Pipeline.Infrastructure.YamlParser do
  @moduledoc """
  Parses raw YAML into pipeline domain entities.

  Handles reading from strings or files and converting YAML maps into
  `PipelineConfig`, `Stage`, `Step`, `Gate`, and `DeployTarget` entities.
  Uses the `yaml_elixir` library for YAML parsing.
  """

  alias Agents.Pipeline.Domain.Entities.{PipelineConfig, Stage, Step, Gate, DeployTarget}

  @doc """
  Parses a YAML string into a `PipelineConfig` entity.

  Returns `{:ok, PipelineConfig.t()}` on success, or `{:error, reason}` on failure.
  Performs structural validation (required keys present) but not business rule
  validation — that is the responsibility of `PipelineConfigPolicy`.
  """
  @spec parse(String.t()) :: {:ok, PipelineConfig.t()} | {:error, term()}
  def parse(yaml_string) when is_binary(yaml_string) do
    with {:ok, raw} <- parse_yaml(yaml_string),
         :ok <- validate_is_map(raw),
         :ok <- validate_required_keys(raw) do
      {:ok, build_config(raw)}
    end
  end

  @doc """
  Reads a YAML file and parses its content into a `PipelineConfig`.

  Accepts a `:file_reader` option for dependency injection in tests.
  Defaults to `File.read/1`.
  """
  @spec parse_file(String.t(), keyword()) :: {:ok, PipelineConfig.t()} | {:error, term()}
  def parse_file(path, opts \\ []) do
    reader = Keyword.get(opts, :file_reader, &File.read/1)

    case reader.(path) do
      {:ok, content} -> parse(content)
      {:error, :enoent} -> {:error, :file_not_found}
      {:error, _reason} -> {:error, :file_not_found}
    end
  end

  # Private helpers

  defp parse_yaml(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :invalid_yaml}
    end
  end

  defp validate_is_map(raw) when is_map(raw), do: :ok
  defp validate_is_map(_), do: {:error, :not_a_map}

  defp validate_required_keys(raw) do
    cond do
      not Map.has_key?(raw, "version") -> {:error, :missing_version}
      not has_stages?(raw) -> {:error, :missing_stages}
      true -> :ok
    end
  end

  defp has_stages?(%{"stages" => stages}) when is_list(stages) and stages != [], do: true
  defp has_stages?(_), do: false

  defp build_config(raw) do
    PipelineConfig.new(%{
      version: raw["version"],
      env: raw["env"] || %{},
      toolchain: raw["toolchain"] || %{},
      services: raw["services"] || %{},
      change_detection: raw["change_detection"] || %{},
      app_surface_map: raw["app_surface_map"] || %{},
      exo_bdd_matrix: raw["exo_bdd_matrix"] || %{},
      js_apps: raw["js_apps"] || %{},
      cache: raw["cache"] || %{},
      images: raw["images"] || %{},
      sessions: raw["sessions"] || %{},
      pull_requests: raw["pull_requests"] || %{},
      stages: parse_stages(raw["stages"] || []),
      deploy_targets: parse_deploy_targets(raw),
      merge_queue: raw["merge_queue"] || %{}
    })
  end

  defp parse_stages(stages) when is_list(stages) do
    Enum.map(stages, &parse_stage/1)
  end

  defp parse_stage(raw) when is_map(raw) do
    Stage.new(%{
      name: raw["name"],
      description: raw["description"],
      trigger: parse_trigger(raw["trigger"]),
      steps: parse_steps(raw["steps"] || []),
      gate: parse_gate(raw["gate"]),
      pool: raw["pool"],
      failure_action: raw["failure_action"] || "block",
      timeout: raw["timeout"]
    })
  end

  defp parse_trigger(nil), do: %{}

  defp parse_trigger(trigger) when is_map(trigger) do
    trigger
    |> normalize_trigger_keys()
  end

  defp normalize_trigger_keys(trigger) do
    trigger
    |> Enum.map(fn
      {"events", v} -> {:events, v}
      {"schedule", v} -> {:schedule, v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp parse_steps(steps) when is_list(steps) do
    Enum.map(steps, &parse_step/1)
  end

  defp parse_step(raw) when is_map(raw) do
    Step.new(%{
      name: raw["name"],
      type: raw["type"] || "command",
      command: raw["command"],
      commands: raw["commands"] || [],
      image: raw["image"],
      env: raw["env"] || %{},
      when_condition: raw["when"]
    })
  end

  defp parse_gate(nil), do: nil

  defp parse_gate(raw) when is_map(raw) do
    Gate.new(%{
      requires: raw["requires"] || [],
      evaluation: raw["evaluation"] || "all_of",
      changes_in: raw["changes_in"] || []
    })
  end

  defp parse_deploy_targets(%{"deploy" => %{"targets" => targets}}) when is_list(targets) do
    Enum.map(targets, &parse_deploy_target/1)
  end

  defp parse_deploy_targets(_), do: []

  defp parse_deploy_target(raw) when is_map(raw) do
    DeployTarget.new(%{
      name: raw["name"],
      type: raw["type"],
      auto_deploy: raw["auto_deploy"] || false,
      config: raw["config"] || Map.drop(raw, ["name", "type", "auto_deploy"])
    })
  end
end

defmodule AgentsWeb.DashboardLive.Components.PipelineEditorComponents do
  @moduledoc "Function components for the dashboard pipeline configuration editor."

  use Phoenix.Component

  attr(:draft, :map, required: true)
  attr(:errors, :list, required: true)
  attr(:saved_at, :any, required: true)
  attr(:saving, :boolean, required: true)
  attr(:file_path, :string, required: true)

  def pipeline_editor(assigns) do
    assigns = assign(assigns, :stages, Map.get(assigns.draft || %{}, "stages", []))

    ~H"""
    <section
      id="pipeline-editor"
      class="border-t border-base-300 bg-base-100/95"
      data-testid="pipeline-editor"
    >
      <div class="px-3 py-3 border-b border-base-300/70 flex items-center gap-2">
        <h3 class="text-sm font-semibold">Pipeline configuration</h3>
        <span :if={@saved_at} class="text-xs text-success">Configuration saved</span>
        <span :if={@saving} class="text-xs text-base-content/60">Saving...</span>
        <button
          type="button"
          phx-click="pipeline_editor_add_stage"
          class="btn btn-xs btn-outline ml-auto"
        >
          Add stage
        </button>
        <button
          type="button"
          phx-click="pipeline_editor_save"
          class="btn btn-xs btn-primary"
          data-testid="pipeline-editor-save"
        >
          Save configuration
        </button>
      </div>

      <div
        :if={@errors != []}
        class="px-3 py-2 text-xs text-error bg-error/10 border-b border-base-300/70"
      >
        <div>Please resolve validation errors before saving</div>
        <div>Changes were not saved</div>
      </div>

      <form id="pipeline-editor-form" phx-change="pipeline_editor_change">
        <div class="px-3 py-3 overflow-x-auto">
          <div class="flex gap-3 min-w-max" data-testid="pipeline-stage-cards">
            <article
              :for={{stage, stage_index} <- Enum.with_index(@stages)}
              class="w-72 rounded-lg border border-base-300 bg-base-200/40 p-3"
              data-testid={"pipeline-stage-card-#{stage_dom_id(stage)}"}
            >
              <div class="flex items-center gap-2">
                <h4 class="text-sm font-semibold">{stage_label(stage)}</h4>
                <button
                  type="button"
                  phx-click="pipeline_editor_move_stage_up"
                  phx-value-stage={stage_index}
                  data-testid={"move-stage-#{stage_dom_id(stage)}-up"}
                  class="btn btn-ghost btn-xs ml-auto"
                >
                  ↑
                </button>
                <button
                  type="button"
                  phx-click="pipeline_editor_move_stage_down"
                  phx-value-stage={stage_index}
                  class="btn btn-ghost btn-xs"
                >
                  ↓
                </button>
                <button
                  type="button"
                  phx-click="pipeline_editor_remove_stage"
                  phx-value-stage={stage_index}
                  data-testid={"remove-stage-#{stage_dom_id(stage)}"}
                  class="btn btn-ghost btn-xs text-error"
                >
                  ✕
                </button>
              </div>

              <div :if={stage_dom_id(stage) == "warm-pool"} class="mt-3 space-y-2">
                <input
                  data-testid="warm-pool-target-count-input"
                  type="number"
                  name={"warm_pool_target_count:#{stage_index}"}
                  value={warm_pool_value(stage, ["target_count"]) || 0}
                  phx-change="pipeline_editor_change"
                  class="input input-xs input-bordered w-full"
                />
                <input
                  data-testid="warm-pool-image-input"
                  type="text"
                  name={"warm_pool_image:#{stage_index}"}
                  value={warm_pool_value(stage, ["image"]) || ""}
                  phx-change="pipeline_editor_change"
                  class="input input-xs input-bordered w-full"
                />
                <input
                  data-testid="warm-pool-step-command-input"
                  type="text"
                  name={"warm_pool_step_run:#{stage_index}"}
                  value={first_step_field(stage, "run")}
                  phx-change="pipeline_editor_change"
                  class="input input-xs input-bordered w-full"
                />
              </div>

              <div class="mt-3 space-y-2">
                <div
                  :for={{step, step_index} <- Enum.with_index(Map.get(stage, "steps", []))}
                  class="rounded border border-base-300 p-2"
                >
                  <input
                    data-testid="step-command-input"
                    type="text"
                    name={"step_run:#{stage_index}:#{step_index}"}
                    value={Map.get(step, "run", "")}
                    phx-change="pipeline_editor_change"
                    class="input input-xs input-bordered w-full mb-1"
                  />
                  <input
                    data-testid="step-timeout-input"
                    type="number"
                    name={"step_timeout:#{stage_index}:#{step_index}"}
                    value={Map.get(step, "timeout_seconds", "")}
                    phx-change="pipeline_editor_change"
                    class="input input-xs input-bordered w-full mb-1"
                  />
                  <input
                    data-testid="step-conditions-input"
                    type="text"
                    name={"step_conditions:#{stage_index}:#{step_index}"}
                    value={Map.get(step, "conditions", "")}
                    phx-change="pipeline_editor_change"
                    class="input input-xs input-bordered w-full mb-1"
                  />
                  <input
                    data-testid="step-env-input"
                    type="text"
                    name={"step_env:#{stage_index}:#{step_index}"}
                    value={first_env_pair(step)}
                    phx-change="pipeline_editor_change"
                    class="input input-xs input-bordered w-full"
                  />
                  <div class="mt-1 flex gap-1">
                    <button
                      type="button"
                      phx-click="pipeline_editor_move_step_down"
                      phx-value-stage={stage_index}
                      phx-value-step={step_index}
                      data-testid={"move-step-#{stage_dom_id(stage)}-#{step_index + 1}-down"}
                      class="btn btn-ghost btn-xs"
                    >
                      ↓
                    </button>
                    <button
                      type="button"
                      phx-click="pipeline_editor_remove_step"
                      phx-value-stage={stage_index}
                      phx-value-step={step_index}
                      data-testid={"remove-step-#{stage_dom_id(stage)}-#{step_index + 1}"}
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Remove step
                    </button>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="pipeline_editor_add_step"
                  phx-value-stage={stage_index}
                  data-testid={"add-step-#{stage_dom_id(stage)}"}
                  class="btn btn-xs btn-outline"
                >
                  Add step
                </button>
                <input
                  data-testid="new-step-command-input"
                  type="text"
                  name={"new_step_command:#{stage_index}"}
                  value=""
                  phx-change="pipeline_editor_change"
                  class="input input-xs input-bordered w-full"
                />
              </div>
            </article>
          </div>
        </div>

        <div class="px-3 pb-3">
          <input
            data-testid="new-stage-name-input"
            type="text"
            name="new_stage_name"
            value=""
            phx-change="pipeline_editor_change"
            class="input input-xs input-bordered w-full"
          />
        </div>
      </form>

      <pre
        class="px-3 py-2 text-xs bg-base-200 border-t border-base-300"
        data-testid="staged-pipeline-preview"
      >
    {preview_lines(@draft)}
      </pre>

      <div class="px-3 py-2 text-xs text-base-content/60 border-t border-base-300">
        <span>{@file_path}</span>
        <span class="ml-2">No staged changes</span>
      </div>
    </section>
    """
  end

  defp stage_label(stage) do
    Map.get(stage, "label") ||
      stage["id"]
      |> to_string()
      |> String.replace("-", " ")
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp stage_dom_id(stage),
    do: stage |> Map.get("id", "stage") |> to_string() |> String.downcase()

  defp warm_pool_value(stage, path) do
    warm_pool = Map.get(stage, "warm_pool") || get_in(stage, ["config", "warm_pool"]) || %{}
    get_in(warm_pool, path)
  end

  defp first_step_field(stage, key) do
    stage
    |> Map.get("steps", [])
    |> List.first()
    |> case do
      nil -> ""
      step -> Map.get(step, key, "")
    end
  end

  defp first_env_pair(step) do
    case Map.get(step, "env", %{}) |> Enum.to_list() |> List.first() do
      {k, v} -> "#{k}=#{v}"
      _ -> ""
    end
  end

  defp preview_lines(draft) do
    stages = Map.get(draft || %{}, "stages", [])

    Enum.map_join(stages, "\n", fn stage ->
      stage_header = "stage: #{stage_label(stage)}"

      warm_pool_lines = preview_warm_pool_lines(stage)
      step_lines = stage |> Map.get("steps", []) |> Enum.flat_map(&preview_step_lines/1)

      Enum.join([stage_header | warm_pool_lines ++ step_lines], "\n")
    end)
  end

  defp preview_warm_pool_lines(stage) do
    case Map.get(stage, "warm_pool") do
      nil ->
        []

      warm_pool ->
        [
          "target_count: #{Map.get(warm_pool, "target_count")}",
          "image: #{Map.get(warm_pool, "image")}"
        ]
    end
  end

  defp preview_step_lines(step) do
    [
      "run: #{Map.get(step, "run")}",
      "timeout_seconds: #{Map.get(step, "timeout_seconds")}",
      "conditions: #{Map.get(step, "conditions")}"
    ] ++ preview_step_env_lines(step)
  end

  defp preview_step_env_lines(step) do
    case Map.get(step, "env", %{}) |> Enum.to_list() |> List.first() do
      {k, v} -> ["#{k}=#{v}"]
      _ -> []
    end
  end
end

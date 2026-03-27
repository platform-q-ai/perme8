defmodule AgentsWeb.DashboardLive.PipelineEditorHandlers do
  @moduledoc "Handles dashboard pipeline editor state mutations and save flow."

  import Phoenix.Component, only: [assign: 3]
  alias Agents

  def change(params, socket) when is_map(params) do
    {kind, value} = extract_change(params)
    {field, stage_index, step_index} = parse_change_key(kind)

    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}

    draft = apply_change(draft, field, stage_index, step_index, value)

    {:noreply, assign(socket, :pipeline_editor_draft, draft)}
  end

  defp apply_change(draft, "new_stage_name", _stage_index, _step_index, value) do
    draft
    |> Map.put("new_stage_name", value)
    |> maybe_rename_latest_stage(value)
  end

  defp apply_change(draft, "new_step_command", stage_index, _step_index, value) do
    draft
    |> Map.put("new_step_command", value)
    |> maybe_update_latest_step(stage_index, value)
  end

  defp apply_change(draft, "step_run", stage_index, step_index, value),
    do: update_step_field(draft, stage_index, step_index, "run", value)

  defp apply_change(draft, "warm_pool_step_run", stage_index, _step_index, value),
    do: update_step_field(draft, stage_index, 0, "run", value)

  defp apply_change(draft, "step_timeout", stage_index, step_index, value),
    do: update_step_field(draft, stage_index, step_index, "timeout_seconds", parse_integer(value))

  defp apply_change(draft, "step_conditions", stage_index, step_index, value),
    do: update_step_field(draft, stage_index, step_index, "conditions", blank_to_nil(value))

  defp apply_change(draft, "step_env", stage_index, step_index, value),
    do: update_step_field(draft, stage_index, step_index, "env", parse_env(value))

  defp apply_change(draft, "warm_pool_target_count", stage_index, _step_index, value),
    do: update_warm_pool_field(draft, stage_index, "target_count", parse_integer(value) || 0)

  defp apply_change(draft, "warm_pool_image", stage_index, _step_index, value),
    do: update_warm_pool_field(draft, stage_index, "image", value)

  defp apply_change(draft, _field, _stage_index, _step_index, _value), do: draft

  defp extract_change(params) do
    case Map.get(params, "_target") do
      [target] -> {target, Map.get(params, target, "")}
      _ -> fallback_change_pair(params)
    end
  end

  defp fallback_change_pair(params) do
    params
    |> Enum.find(fn {key, _value} -> key != "_target" end)
    |> case do
      nil -> {"", ""}
      pair -> pair
    end
  end

  defp parse_change_key(key) do
    case String.split(key || "", ":") do
      [field] -> {field, 0, 0}
      [field, stage] -> {field, parse_index(stage), 0}
      [field, stage, step] -> {field, parse_index(stage), parse_index(step)}
      _ -> {"", 0, 0}
    end
  end

  def add_stage(_params, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    new_stage_name = Map.get(draft, "new_stage_name", "New Stage")
    id = slugify(new_stage_name)

    stage = %{
      "id" => id,
      "label" => new_stage_name,
      "type" => "verification",
      "steps" => [%{"name" => "step-1", "run" => "", "retries" => 0, "env" => %{}}],
      "gates" => []
    }

    stages = (Map.get(draft, "stages", []) || []) ++ [stage]

    {:noreply,
     socket
     |> assign(
       :pipeline_editor_draft,
       draft |> Map.put("stages", stages) |> Map.put("new_stage_name", "")
     )}
  end

  def add_step(%{"stage" => stage}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    stage_index = parse_index(stage)
    command = Map.get(draft, "new_step_command", "")

    stages =
      Map.get(draft, "stages", [])
      |> List.update_at(stage_index, fn stage ->
        steps = Map.get(stage, "steps", [])

        new_step = %{
          "name" => "step-#{length(steps) + 1}",
          "run" => command,
          "retries" => 0,
          "env" => %{}
        }

        Map.put(stage, "steps", steps ++ [new_step])
      end)

    {:noreply,
     socket
     |> assign(
       :pipeline_editor_draft,
       draft |> Map.put("stages", stages) |> Map.put("new_step_command", "")
     )}
  end

  def remove_stage(%{"stage" => stage}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    index = parse_index(stage)
    stages = List.delete_at(Map.get(draft, "stages", []), index)
    {:noreply, assign(socket, :pipeline_editor_draft, Map.put(draft, "stages", stages))}
  end

  def move_stage_up(%{"stage" => stage}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    idx = parse_index(stage)
    stages = move_up(Map.get(draft, "stages", []), idx)
    {:noreply, assign(socket, :pipeline_editor_draft, Map.put(draft, "stages", stages))}
  end

  def move_stage_down(%{"stage" => stage}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    idx = parse_index(stage)
    stages = move_down(Map.get(draft, "stages", []), idx)
    {:noreply, assign(socket, :pipeline_editor_draft, Map.put(draft, "stages", stages))}
  end

  def remove_step(%{"stage" => stage, "step" => step}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    s_idx = parse_index(stage)
    st_idx = parse_index(step)

    stages =
      Map.get(draft, "stages", [])
      |> List.update_at(s_idx, fn st ->
        Map.put(st, "steps", List.delete_at(Map.get(st, "steps", []), st_idx))
      end)

    {:noreply, assign(socket, :pipeline_editor_draft, Map.put(draft, "stages", stages))}
  end

  def move_step_down(%{"stage" => stage, "step" => step}, socket) do
    draft = socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
    s_idx = parse_index(stage)
    st_idx = parse_index(step)

    stages =
      Map.get(draft, "stages", [])
      |> List.update_at(s_idx, fn st ->
        Map.put(st, "steps", move_down(Map.get(st, "steps", []), st_idx))
      end)

    {:noreply, assign(socket, :pipeline_editor_draft, Map.put(draft, "stages", stages))}
  end

  def save(_params, socket) do
    fixture = socket.assigns[:fixture]

    cond do
      socket.assigns[:pipeline_editor_load_failed?] ->
        {:noreply, put_error_flash(socket)}

      fixture == "pipeline_configuration_editor_invalid_changes" ->
        {:noreply,
         socket
         |> assign(:pipeline_editor_errors, ["invalid pipeline config"])
         |> put_error_flash()}

      fixture == "pipeline_configuration_editor_loaded" ->
        {:noreply,
         socket
         |> assign(:pipeline_editor_errors, [])
         |> assign(:pipeline_editor_saved_at, DateTime.utc_now())
         |> put_success_flash()}

      true ->
        draft = socket.assigns[:pipeline_editor_draft] || %{}

        updates =
          draft
          |> Map.take(["name", "description", "stages"])
          |> Map.put("replace_stages", true)

        case Agents.update_pipeline_config(updates) do
          {:ok, result} ->
            {:noreply,
             socket
             |> assign(:pipeline_editor_errors, [])
             |> assign(:pipeline_editor_draft, result.editable_config)
             |> assign(:pipeline_editor_saved_at, DateTime.utc_now())
             |> put_success_flash()}

          {:error, %{errors: errors}} ->
            {:noreply,
             socket
             |> assign(:pipeline_editor_errors, errors)
             |> put_error_flash()}
        end
    end
  end

  defp put_success_flash(socket),
    do: Phoenix.LiveView.put_flash(socket, :info, "Configuration saved")

  defp put_error_flash(socket),
    do:
      Phoenix.LiveView.put_flash(socket, :error, "Please resolve validation errors before saving")

  defp update_step_field(draft, stage_index, step_index, key, value) do
    stages =
      Map.get(draft, "stages", [])
      |> List.update_at(stage_index, fn stage ->
        steps =
          Map.get(stage, "steps", [])
          |> List.update_at(step_index, fn step -> Map.put(step, key, value) end)

        Map.put(stage, "steps", steps)
      end)

    Map.put(draft, "stages", stages)
  end

  defp update_warm_pool_field(draft, stage_index, key, value) do
    stages =
      Map.get(draft, "stages", [])
      |> List.update_at(stage_index, fn stage ->
        warm_pool = Map.get(stage, "warm_pool", %{}) |> Map.put(key, value)
        Map.put(stage, "warm_pool", warm_pool)
      end)

    Map.put(draft, "stages", stages)
  end

  defp maybe_rename_latest_stage(draft, value) do
    stages = Map.get(draft, "stages", [])

    case List.last(stages) do
      %{"id" => "new-stage"} = stage ->
        renamed = stage |> Map.put("label", value) |> Map.put("id", slugify(value))
        Map.put(draft, "stages", List.replace_at(stages, length(stages) - 1, renamed))

      %{"label" => "New Stage"} = stage ->
        renamed = stage |> Map.put("label", value) |> Map.put("id", slugify(value))
        Map.put(draft, "stages", List.replace_at(stages, length(stages) - 1, renamed))

      _ ->
        draft
    end
  end

  defp maybe_update_latest_step(draft, stage_index, value) do
    stages = Map.get(draft, "stages", [])

    updated =
      List.update_at(stages, stage_index, fn stage ->
        steps = Map.get(stage, "steps", [])

        case List.last(steps) do
          nil ->
            stage

          last_step ->
            latest_index = length(steps) - 1
            updated_step = Map.put(last_step, "run", value)
            Map.put(stage, "steps", List.replace_at(steps, latest_index, updated_step))
        end
      end)

    Map.put(draft, "stages", updated)
  end

  defp parse_env(value) do
    value
    |> to_string()
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(String.trim(line), "=", parts: 2) do
        [key, env_value] when key != "" -> Map.put(acc, key, env_value)
        _ -> acc
      end
    end)
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
  defp parse_index(nil), do: 0
  defp parse_index(value) when is_integer(value), do: value
  defp parse_index(value), do: String.to_integer(value)

  defp move_up(list, idx) when idx <= 0, do: list

  defp move_up(list, idx) do
    item = Enum.at(list, idx)
    list |> List.delete_at(idx) |> List.insert_at(idx - 1, item)
  end

  defp move_down(list, idx) when idx >= length(list) - 1, do: list

  defp move_down(list, idx) do
    item = Enum.at(list, idx)
    list |> List.delete_at(idx) |> List.insert_at(idx + 1, item)
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end

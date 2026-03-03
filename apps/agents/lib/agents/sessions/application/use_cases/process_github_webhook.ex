defmodule Agents.Sessions.Application.UseCases.ProcessGithubWebhook do
  @moduledoc """
  Dispatches GitHub webhook events into automated coding sessions.
  """

  alias Agents.Sessions.Application.GithubWebhookConfig

  @spec execute(binary(), map(), keyword()) ::
          {:ok, {:queued, map()}} | {:ok, :ignored} | {:error, term()}
  def execute(event, payload, opts \\ []) when is_binary(event) and is_map(payload) do
    bot_identity = GithubWebhookConfig.bot_identity()

    with :ok <- validate_enabled(),
         :ok <- validate_repo(payload),
         {:ok, instruction} <- build_instruction(event, payload, bot_identity) do
      case instruction do
        :ignored ->
          {:ok, :ignored}

        _ ->
          case validate_automation_user() do
            :ok -> queue_task(instruction, event, bot_identity, opts)
            error -> error
          end
      end
    else
      error -> error
    end
  end

  defp validate_enabled do
    if GithubWebhookConfig.enabled?(), do: :ok, else: {:error, :automation_disabled}
  end

  defp validate_repo(%{"repository" => %{"full_name" => repo}}) when is_binary(repo) do
    if repo == GithubWebhookConfig.repo(), do: :ok, else: {:ok, :ignored}
  end

  defp validate_repo(_), do: {:error, :invalid_payload}

  defp validate_automation_user do
    case GithubWebhookConfig.automation_user_id() do
      id when is_binary(id) and id != "" -> :ok
      _ -> {:error, :missing_automation_user_id}
    end
  end

  defp build_instruction("pull_request", payload, bot_identity) do
    action = payload["action"]

    if action in ["opened", "reopened", "synchronize", "ready_for_review"] do
      with {:ok, number} <- pull_request_number(payload),
           {:ok, branch} <- branch_ref(payload) do
        {:ok,
         "Review PR ##{number} in #{GithubWebhookConfig.repo()} (action: #{action}, branch: #{branch}) using #{bot_identity} identity."}
      end
    else
      {:ok, :ignored}
    end
  end

  defp build_instruction("pull_request_review", payload, bot_identity) do
    state = get_in(payload, ["review", "state"])

    if payload["action"] == "submitted" and state == "changes_requested" do
      with {:ok, number} <- pull_request_number(payload) do
        {:ok,
         "Address PR comments for ##{number} in #{GithubWebhookConfig.repo()} after changes requested review, then push fixes as #{bot_identity}."}
      end
    else
      {:ok, :ignored}
    end
  end

  defp build_instruction("pull_request_review_comment", payload, bot_identity) do
    if payload["action"] == "created" and not automation_sender?(payload, bot_identity) do
      with {:ok, number} <- pull_request_number(payload) do
        {:ok,
         "Address PR comments for ##{number} in #{GithubWebhookConfig.repo()} based on new review comment, using #{bot_identity} identity."}
      end
    else
      {:ok, :ignored}
    end
  end

  defp build_instruction("issue_comment", payload, bot_identity) do
    with "created" <- payload["action"],
         %{} <- payload["issue"]["pull_request"],
         {:ok, number} <- issue_number(payload) do
      {:ok,
       "Address PR comments for ##{number} in #{GithubWebhookConfig.repo()} based on new issue comment on the PR, using #{bot_identity}."}
    else
      _ -> {:ok, :ignored}
    end
  end

  defp build_instruction("merge_group", payload, bot_identity) do
    if payload["action"] == "checks_requested" do
      merge_group = payload["merge_group"] || %{}
      head_sha = merge_group["head_sha"] || "unknown"
      base_ref = merge_group["base_ref"] || "unknown"

      {:ok,
       "Handle merge queue rebase and CI readiness for #{GithubWebhookConfig.repo()} (base: #{base_ref}, head: #{head_sha}) using #{bot_identity} identity."}
    else
      {:ok, :ignored}
    end
  end

  defp build_instruction(_event, _payload, _bot_identity), do: {:ok, :ignored}

  defp queue_task(instruction, event, bot_identity, opts) do
    create_task_fn = Keyword.get(opts, :create_task_fn)

    if is_function(create_task_fn, 1) do
      attrs = %{
        instruction: instruction,
        user_id: GithubWebhookConfig.automation_user_id(),
        image: GithubWebhookConfig.image()
      }

      case create_task_fn.(attrs) do
        {:ok, task} ->
          {:ok,
           {:queued,
            %{
              task_id: task.id,
              event: event,
              bot_identity: bot_identity
            }}}

        {:error, reason} ->
          {:error, {:task_creation_failed, reason}}
      end
    else
      {:error, :missing_create_task_fn}
    end
  end

  defp automation_sender?(payload, bot_identity) do
    case get_in(payload, ["sender", "login"]) do
      login when is_binary(login) ->
        normalized = String.downcase(login)
        normalized in [String.downcase(bot_identity), "app/perme8"]

      _ ->
        false
    end
  end

  defp pull_request_number(%{"pull_request" => %{"number" => number}}) when is_integer(number),
    do: {:ok, number}

  defp pull_request_number(%{"number" => number}) when is_integer(number), do: {:ok, number}
  defp pull_request_number(_), do: {:error, :invalid_payload}

  defp issue_number(%{"issue" => %{"number" => number}}) when is_integer(number),
    do: {:ok, number}

  defp issue_number(_), do: {:error, :invalid_payload}

  defp branch_ref(%{"pull_request" => %{"head" => %{"ref" => ref}}}) when is_binary(ref),
    do: {:ok, ref}

  defp branch_ref(_), do: {:error, :invalid_payload}
end

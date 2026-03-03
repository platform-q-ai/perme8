defmodule Agents.Sessions.Application.UseCases.ProcessGithubWebhookTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.UseCases.ProcessGithubWebhook

  setup do
    original = Application.get_env(:agents, :github_webhook)

    Application.put_env(:agents, :github_webhook,
      enabled: true,
      secret: "test-secret",
      automation_user_id: "user-123",
      repo: "platform-q-ai/perme8",
      image: "ghcr.io/platform-q-ai/perme8-opencode:latest",
      bot_identity: "perme8[bot]"
    )

    on_exit(fn ->
      if original do
        Application.put_env(:agents, :github_webhook, original)
      else
        Application.delete_env(:agents, :github_webhook)
      end
    end)

    :ok
  end

  test "queues review task for pull_request synchronize event" do
    payload = %{
      "action" => "synchronize",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280, "head" => %{"ref" => "feat/test"}}
    }

    create_task_fn = fn attrs ->
      assert attrs.user_id == "user-123"
      assert attrs.image == "ghcr.io/platform-q-ai/perme8-opencode:latest"
      assert attrs.instruction =~ "Review PR #280"
      {:ok, %{id: "task-1"}}
    end

    assert {:ok, {:queued, %{task_id: "task-1", event: "pull_request"}}} =
             ProcessGithubWebhook.execute("pull_request", payload, create_task_fn: create_task_fn)
  end

  test "queues comment handling task for changes requested review" do
    payload = %{
      "action" => "submitted",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280},
      "review" => %{"state" => "changes_requested"}
    }

    create_task_fn = fn attrs ->
      assert attrs.instruction =~ "Address PR comments"
      {:ok, %{id: "task-2"}}
    end

    assert {:ok, {:queued, %{task_id: "task-2", event: "pull_request_review"}}} =
             ProcessGithubWebhook.execute("pull_request_review", payload,
               create_task_fn: create_task_fn
             )
  end

  test "ignores pull_request_review_comment events from automation identities" do
    payload = %{
      "action" => "created",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280},
      "sender" => %{"login" => "perme8[bot]"}
    }

    assert {:ok, :ignored} =
             ProcessGithubWebhook.execute("pull_request_review_comment", payload,
               create_task_fn: fn _ -> flunk("should not queue task") end
             )
  end

  test "queues pull_request_review_comment events from human reviewers" do
    payload = %{
      "action" => "created",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280},
      "sender" => %{"login" => "perme8"}
    }

    create_task_fn = fn attrs ->
      assert attrs.instruction =~ "Address PR comments"
      {:ok, %{id: "task-3"}}
    end

    assert {:ok, {:queued, %{task_id: "task-3", event: "pull_request_review_comment"}}} =
             ProcessGithubWebhook.execute("pull_request_review_comment", payload,
               create_task_fn: create_task_fn
             )
  end

  test "ignores unsupported actions" do
    payload = %{
      "action" => "edited",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280, "head" => %{"ref" => "feat/test"}}
    }

    assert {:ok, :ignored} = ProcessGithubWebhook.execute("pull_request", payload)
  end

  test "ignores unsupported actions even when automation user id is missing" do
    Application.put_env(:agents, :github_webhook,
      enabled: true,
      secret: "test-secret",
      automation_user_id: nil,
      repo: "platform-q-ai/perme8",
      image: "ghcr.io/platform-q-ai/perme8-opencode:latest",
      bot_identity: "perme8[bot]"
    )

    payload = %{
      "action" => "edited",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280, "head" => %{"ref" => "feat/test"}}
    }

    assert {:ok, :ignored} = ProcessGithubWebhook.execute("pull_request", payload)
  end

  test "ignores events for other repositories" do
    payload = %{
      "action" => "opened",
      "repository" => %{"full_name" => "platform-q-ai/other-repo"},
      "pull_request" => %{"number" => 280, "head" => %{"ref" => "feat/test"}}
    }

    assert {:ok, :ignored} = ProcessGithubWebhook.execute("pull_request", payload)
  end

  test "returns error when automation user id is missing" do
    Application.put_env(:agents, :github_webhook,
      enabled: true,
      secret: "test-secret",
      automation_user_id: nil,
      repo: "platform-q-ai/perme8",
      image: "ghcr.io/platform-q-ai/perme8-opencode:latest",
      bot_identity: "perme8[bot]"
    )

    payload = %{
      "action" => "opened",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280, "head" => %{"ref" => "feat/test"}}
    }

    assert {:error, :missing_automation_user_id} =
             ProcessGithubWebhook.execute("pull_request", payload)
  end
end

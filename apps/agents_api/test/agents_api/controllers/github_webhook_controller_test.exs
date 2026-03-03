defmodule AgentsApi.GithubWebhookControllerTest do
  use AgentsApi.ConnCase, async: true

  @secret "webhook-secret"

  setup do
    original_webhook_config = Application.get_env(:agents, :github_webhook)
    original_processor = Application.get_env(:agents_api, :github_webhook_processor)

    Application.put_env(:agents, :github_webhook,
      enabled: true,
      secret: @secret,
      automation_user_id: "user-123",
      repo: "platform-q-ai/perme8",
      image: "ghcr.io/platform-q-ai/perme8-opencode:latest",
      bot_identity: "perme8[bot]"
    )

    on_exit(fn ->
      if original_webhook_config do
        Application.put_env(:agents, :github_webhook, original_webhook_config)
      else
        Application.delete_env(:agents, :github_webhook)
      end

      if original_processor do
        Application.put_env(:agents_api, :github_webhook_processor, original_processor)
      else
        Application.delete_env(:agents_api, :github_webhook_processor)
      end
    end)

    :ok
  end

  test "returns 202 and task details for valid webhook", %{conn: conn} do
    Application.put_env(:agents_api, :github_webhook_processor, __MODULE__.QueueingProcessor)

    payload = %{
      "action" => "opened",
      "repository" => %{"full_name" => "platform-q-ai/perme8"},
      "pull_request" => %{"number" => 280}
    }

    body = Jason.encode!(payload)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-github-event", "pull_request")
      |> put_req_header("x-hub-signature-256", signature_for(body))
      |> post("/api/github/webhooks", body)
      |> json_response(202)

    assert %{
             "status" => "queued",
             "details" => %{"event" => "pull_request", "task_id" => "task-123"}
           } = response
  end

  test "returns 401 for invalid signature", %{conn: conn} do
    payload = %{"repository" => %{"full_name" => "platform-q-ai/perme8"}}

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-github-event", "pull_request")
    |> put_req_header("x-hub-signature-256", "sha256=invalid")
    |> post("/api/github/webhooks", Jason.encode!(payload))
    |> json_response(401)
  end

  test "returns 202 ignored when processor ignores event", %{conn: conn} do
    Application.put_env(:agents_api, :github_webhook_processor, __MODULE__.IgnoreProcessor)

    payload = %{"repository" => %{"full_name" => "platform-q-ai/perme8"}}
    body = Jason.encode!(payload)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-github-event", "issues")
      |> put_req_header("x-hub-signature-256", signature_for(body))
      |> post("/api/github/webhooks", body)
      |> json_response(202)

    assert %{"status" => "ignored"} = response
  end

  test "returns stable message for task creation failures", %{conn: conn} do
    Application.put_env(:agents_api, :github_webhook_processor, __MODULE__.TaskFailureProcessor)

    payload = %{"repository" => %{"full_name" => "platform-q-ai/perme8"}}
    body = Jason.encode!(payload)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-github-event", "pull_request")
      |> put_req_header("x-hub-signature-256", signature_for(body))
      |> post("/api/github/webhooks", body)
      |> json_response(422)

    assert %{"error" => "Failed to queue task"} = response
  end

  test "returns stable message for generic processing failures", %{conn: conn} do
    Application.put_env(:agents_api, :github_webhook_processor, __MODULE__.FailureProcessor)

    payload = %{"repository" => %{"full_name" => "platform-q-ai/perme8"}}
    body = Jason.encode!(payload)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-github-event", "pull_request")
      |> put_req_header("x-hub-signature-256", signature_for(body))
      |> post("/api/github/webhooks", body)
      |> json_response(422)

    assert %{"error" => "Webhook processing failed"} = response
  end

  defp signature_for(body) do
    digest = :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)
    "sha256=#{digest}"
  end

  defmodule QueueingProcessor do
    def process("pull_request", _payload) do
      {:ok, {:queued, %{task_id: "task-123", event: "pull_request", bot_identity: "perme8[bot]"}}}
    end
  end

  defmodule IgnoreProcessor do
    def process(_event, _payload), do: {:ok, :ignored}
  end

  defmodule TaskFailureProcessor do
    def process(_event, _payload),
      do: {:error, {:task_creation_failed, %{details: "secret info"}}}
  end

  defmodule FailureProcessor do
    def process(_event, _payload), do: {:error, {:unexpected, "secret info"}}
  end
end

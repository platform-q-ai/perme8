defmodule Agents.Sessions.Infrastructure.Clients.OpencodeClientTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.Clients.OpencodeClient

  describe "health/1" do
    test "returns :ok when health endpoint responds 200" do
      http = fn :get, url, _opts ->
        assert url == "http://localhost:4096/global/health"
        {:ok, %{status: 200, body: %{"status" => "healthy"}}}
      end

      assert :ok = OpencodeClient.health("http://localhost:4096", http: http)
    end

    test "returns error when endpoint fails" do
      http = fn :get, _url, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end

      assert {:error, _} = OpencodeClient.health("http://localhost:4096", http: http)
    end

    test "returns error for non-200 status" do
      http = fn :get, _url, _opts ->
        {:ok, %{status: 503, body: %{"status" => "unavailable"}}}
      end

      assert {:error, :unhealthy} =
               OpencodeClient.health("http://localhost:4096", http: http)
    end
  end

  describe "create_session/2" do
    test "returns session data on 200" do
      http = fn :post, url, _opts ->
        assert url == "http://localhost:4096/session"
        {:ok, %{status: 200, body: %{"id" => "sess-123", "created" => true}}}
      end

      assert {:ok, %{"id" => "sess-123"}} =
               OpencodeClient.create_session("http://localhost:4096", http: http)
    end

    test "returns error on failure" do
      http = fn :post, _url, _opts ->
        {:ok, %{status: 500, body: %{"error" => "internal error"}}}
      end

      assert {:error, _} =
               OpencodeClient.create_session("http://localhost:4096", http: http)
    end
  end

  describe "send_prompt_async/4" do
    test "returns :ok on 204 (accepted)" do
      http = fn :post, url, _opts ->
        assert String.contains?(url, "/session/sess-123/prompt_async")
        {:ok, %{status: 204, body: ""}}
      end

      assert :ok =
               OpencodeClient.send_prompt_async(
                 "http://localhost:4096",
                 "sess-123",
                 [%{type: "text", text: "Write tests"}],
                 http: http
               )
    end

    test "returns :ok on 200 (legacy compat)" do
      http = fn :post, _url, _opts ->
        {:ok, %{status: 200, body: %{"ok" => true}}}
      end

      assert :ok =
               OpencodeClient.send_prompt_async(
                 "http://localhost:4096",
                 "sess-123",
                 [%{type: "text", text: "Write tests"}],
                 http: http
               )
    end

    test "returns error on failure" do
      http = fn :post, _url, _opts ->
        {:ok, %{status: 400, body: %{"error" => "bad request"}}}
      end

      assert {:error, _} =
               OpencodeClient.send_prompt_async(
                 "http://localhost:4096",
                 "sess-123",
                 [%{type: "text", text: "Write tests"}],
                 http: http
               )
    end
  end

  describe "abort_session/2" do
    test "returns ok on successful abort" do
      http = fn :post, url, _opts ->
        assert String.contains?(url, "/session/sess-123/abort")
        {:ok, %{status: 200, body: %{"aborted" => true}}}
      end

      assert {:ok, true} =
               OpencodeClient.abort_session("http://localhost:4096", "sess-123", http: http)
    end
  end

  describe "reply_permission/5" do
    test "returns :ok on 200" do
      http = fn :post, url, opts ->
        assert String.contains?(url, "/session/sess-1/permissions/perm-1")
        body = Keyword.get(opts, :json)
        assert body.response == "always"
        {:ok, %{status: 200, body: true}}
      end

      assert :ok =
               OpencodeClient.reply_permission(
                 "http://localhost:4096",
                 "sess-1",
                 "perm-1",
                 "always",
                 http: http
               )
    end

    test "returns :ok on 204" do
      http = fn :post, _url, _opts ->
        {:ok, %{status: 204, body: ""}}
      end

      assert :ok =
               OpencodeClient.reply_permission(
                 "http://localhost:4096",
                 "sess-1",
                 "perm-1",
                 "once",
                 http: http
               )
    end
  end

  describe "list_sessions/2" do
    test "returns list when response is an array" do
      http = fn :get, url, _opts ->
        assert url == "http://localhost:4096/session"

        {:ok,
         %{
           status: 200,
           body: [%{"id" => "sess-1", "title" => "Session 1"}, %{"id" => "sess-2"}]
         }}
      end

      assert {:ok, sessions} =
               OpencodeClient.list_sessions("http://localhost:4096", http: http)

      assert length(sessions) == 2
      assert Enum.at(sessions, 0)["id"] == "sess-1"
    end

    test "returns list when response is wrapped in data key" do
      http = fn :get, _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{"data" => [%{"id" => "sess-1"}]}
         }}
      end

      assert {:ok, [%{"id" => "sess-1"}]} =
               OpencodeClient.list_sessions("http://localhost:4096", http: http)
    end

    test "returns error on failure" do
      http = fn :get, _url, _opts ->
        {:ok, %{status: 500, body: %{"error" => "internal"}}}
      end

      assert {:error, {:http_error, 500, _}} =
               OpencodeClient.list_sessions("http://localhost:4096", http: http)
    end
  end

  describe "get_session/3" do
    test "returns session data on 200" do
      http = fn :get, url, _opts ->
        assert url == "http://localhost:4096/session/sess-123"
        {:ok, %{status: 200, body: %{"id" => "sess-123", "title" => "My Session"}}}
      end

      assert {:ok, %{"id" => "sess-123", "title" => "My Session"}} =
               OpencodeClient.get_session("http://localhost:4096", "sess-123", http: http)
    end

    test "returns error on 404" do
      http = fn :get, _url, _opts ->
        {:ok, %{status: 404, body: %{"error" => "not found"}}}
      end

      assert {:error, {:http_error, 404, _}} =
               OpencodeClient.get_session("http://localhost:4096", "sess-123", http: http)
    end

    test "returns error on connection failure" do
      http = fn :get, _url, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end

      assert {:error, %Req.TransportError{}} =
               OpencodeClient.get_session("http://localhost:4096", "sess-123", http: http)
    end
  end

  describe "get_messages/3" do
    test "returns messages when response is an array" do
      http = fn :get, url, _opts ->
        assert url == "http://localhost:4096/session/sess-123/message"

        {:ok,
         %{
           status: 200,
           body: [
             %{
               "id" => "msg-1",
               "role" => "user",
               "parts" => [%{"type" => "text", "text" => "Hello"}]
             },
             %{
               "id" => "msg-2",
               "role" => "assistant",
               "parts" => [%{"type" => "text", "text" => "Hi!"}]
             }
           ]
         }}
      end

      assert {:ok, messages} =
               OpencodeClient.get_messages("http://localhost:4096", "sess-123", http: http)

      assert length(messages) == 2
      assert Enum.at(messages, 0)["role"] == "user"
      assert Enum.at(messages, 1)["role"] == "assistant"
    end

    test "returns messages when response is wrapped in data key" do
      http = fn :get, _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{"data" => [%{"id" => "msg-1", "role" => "user"}]}
         }}
      end

      assert {:ok, [%{"id" => "msg-1"}]} =
               OpencodeClient.get_messages("http://localhost:4096", "sess-123", http: http)
    end

    test "returns error on failure" do
      http = fn :get, _url, _opts ->
        {:ok, %{status: 500, body: %{"error" => "internal"}}}
      end

      assert {:error, {:http_error, 500, _}} =
               OpencodeClient.get_messages("http://localhost:4096", "sess-123", http: http)
    end
  end

  describe "set_auth/4" do
    test "returns {:ok, true} on successful 200" do
      http = fn :put, url, opts ->
        assert url == "http://localhost:4096/auth/anthropic"
        body = Keyword.get(opts, :json)
        assert body["type"] == "api"
        assert body["key"] == "sk-ant-test"
        {:ok, %{status: 200, body: true}}
      end

      assert {:ok, true} =
               OpencodeClient.set_auth(
                 "http://localhost:4096",
                 "anthropic",
                 %{"type" => "api", "key" => "sk-ant-test"},
                 http: http
               )
    end

    test "returns error on non-200 status" do
      http = fn :put, _url, _opts ->
        {:ok, %{status: 400, body: %{"error" => "invalid credentials"}}}
      end

      assert {:error, {:http_error, 400, _}} =
               OpencodeClient.set_auth(
                 "http://localhost:4096",
                 "anthropic",
                 %{"type" => "api", "key" => "bad"},
                 http: http
               )
    end

    test "returns error on connection failure" do
      http = fn :put, _url, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end

      assert {:error, %Req.TransportError{}} =
               OpencodeClient.set_auth(
                 "http://localhost:4096",
                 "anthropic",
                 %{},
                 http: http
               )
    end
  end

  describe "list_providers/2" do
    test "returns provider data on 200" do
      http = fn :get, url, _opts ->
        assert url == "http://localhost:4096/provider"

        {:ok,
         %{
           status: 200,
           body: %{
             "all" => [%{"id" => "anthropic"}, %{"id" => "openrouter"}],
             "connected" => ["anthropic"],
             "default" => %{}
           }
         }}
      end

      assert {:ok, %{"connected" => ["anthropic"]}} =
               OpencodeClient.list_providers("http://localhost:4096", http: http)
    end

    test "returns error on failure" do
      http = fn :get, _url, _opts ->
        {:ok, %{status: 500, body: %{"error" => "internal"}}}
      end

      assert {:error, {:http_error, 500, _}} =
               OpencodeClient.list_providers("http://localhost:4096", http: http)
    end
  end

  describe "subscribe_events/2" do
    test "spawns process that forwards SSE events" do
      test_pid = self()

      http = fn :get, url, _opts ->
        assert String.contains?(url, "/event")
        send(test_pid, :subscribed)
        {:ok, %{status: 200, body: ""}}
      end

      assert {:ok, _pid} =
               OpencodeClient.subscribe_events("http://localhost:4096", test_pid, http: http)

      assert_receive :subscribed, 1000
    end
  end

  describe "parse_sse_chunk/1" do
    test "parses a complete SSE message" do
      raw =
        "event: session.status\ndata: {\"sessionID\":\"s1\",\"status\":{\"type\":\"running\"}}\n\n"

      {events, remaining} = OpencodeClient.parse_sse_chunk(raw)

      assert length(events) == 1
      [event] = events
      assert event["type"] == "session.status"
      assert event["sessionID"] == "s1"
      assert remaining == ""
    end

    test "parses multiple complete SSE messages" do
      raw =
        ~s(event: server.connected\ndata: {"version":"1.2.10"}\n\n) <>
          ~s(event: session.status\ndata: {"sessionID":"s1","status":{"type":"running"}}\n\n)

      {events, remaining} = OpencodeClient.parse_sse_chunk(raw)

      assert length(events) == 2
      assert Enum.at(events, 0)["type"] == "server.connected"
      assert Enum.at(events, 1)["type"] == "session.status"
      assert remaining == ""
    end

    test "handles incomplete messages in buffer" do
      raw = "event: session.status\ndata: {\"partial\":"

      {events, remaining} = OpencodeClient.parse_sse_chunk(raw)

      assert events == []
      assert remaining == raw
    end

    test "parses permission.asked event" do
      raw =
        "event: permission.asked\ndata: {\"id\":\"perm-1\",\"permission\":\"bash\"}\n\n"

      {[event], _} = OpencodeClient.parse_sse_chunk(raw)

      assert event["type"] == "permission.asked"
      assert event["id"] == "perm-1"
      assert event["permission"] == "bash"
    end

    test "parses message.part.updated event" do
      raw =
        "event: message.part.updated\ndata: {\"part\":{\"type\":\"text\",\"text\":\"Hello\"}}\n\n"

      {[event], _} = OpencodeClient.parse_sse_chunk(raw)

      assert event["type"] == "message.part.updated"
      assert get_in(event, ["part", "text"]) == "Hello"
    end
  end
end

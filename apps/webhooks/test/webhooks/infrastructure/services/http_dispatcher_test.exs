defmodule Webhooks.Infrastructure.Services.HttpDispatcherTest do
  use ExUnit.Case, async: true

  alias Webhooks.Infrastructure.Services.HttpDispatcher

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  describe "dispatch/3" do
    test "dispatches POST request with JSON payload and returns success", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert body == ~s({"event":"test"})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok"}))
      end)

      headers = [
        {"content-type", "application/json"},
        {"x-webhook-signature", "sha256=abc123"}
      ]

      assert {:ok, 200, body} =
               HttpDispatcher.dispatch("#{base_url}/webhook", ~s({"event":"test"}), headers)

      # Req auto-decodes JSON responses to maps
      assert body == %{"status" => "ok"}
    end

    test "includes custom headers in request", %{bypass: bypass, base_url: base_url} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        headers = Map.new(conn.req_headers)
        send(test_pid, {:headers, headers})

        conn
        |> Plug.Conn.resp(200, "ok")
      end)

      headers = [
        {"content-type", "application/json"},
        {"x-webhook-signature", "sha256=test_sig"}
      ]

      assert {:ok, 200, _} =
               HttpDispatcher.dispatch("#{base_url}/webhook", "{}", headers)

      assert_receive {:headers, headers}
      assert headers["x-webhook-signature"] == "sha256=test_sig"
      assert headers["content-type"] == "application/json"
    end

    test "returns {:ok, status_code, body} for non-2xx responses", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.resp(500, "Internal Server Error")
      end)

      assert {:ok, 500, "Internal Server Error"} =
               HttpDispatcher.dispatch("#{base_url}/webhook", "{}", [])
    end

    test "returns {:error, reason} on connection failure", %{bypass: bypass, base_url: base_url} do
      Bypass.down(bypass)

      assert {:error, _reason} =
               HttpDispatcher.dispatch("#{base_url}/webhook", "{}", [])
    end
  end
end

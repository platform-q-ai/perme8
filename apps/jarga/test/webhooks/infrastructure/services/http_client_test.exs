defmodule Jarga.Webhooks.Infrastructure.Services.HttpClientTest do
  use ExUnit.Case, async: false

  alias Jarga.Webhooks.Infrastructure.Services.HttpClient

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    {:ok, bypass: bypass, base_url: base_url}
  end

  describe "post/3" do
    test "sends HTTP POST with JSON body and returns success", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded == %{"event" => "test"}

        # Verify Content-Type header
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
      end)

      assert {:ok, %{status: 200, body: body}} =
               HttpClient.post("#{base_url}/webhook", %{"event" => "test"})

      assert body =~ "ok"
    end

    test "sends X-Webhook-Signature header when provided", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        [sig] = Plug.Conn.get_req_header(conn, "x-webhook-signature")
        assert sig == "sha256=abc123"

        conn
        |> Plug.Conn.resp(200, "OK")
      end)

      assert {:ok, _} =
               HttpClient.post("#{base_url}/webhook", %{"event" => "test"},
                 headers: %{"X-Webhook-Signature" => "sha256=abc123"}
               )
    end

    test "returns error on connection failure" do
      assert {:error, _reason} = HttpClient.post("http://localhost:1/webhook", %{})
    end

    test "returns ok with non-2xx status code", %{bypass: bypass, base_url: base_url} do
      Bypass.expect_once(bypass, "POST", "/webhook", fn conn ->
        conn
        |> Plug.Conn.resp(500, "Internal Server Error")
      end)

      assert {:ok, %{status: 500, body: "Internal Server Error"}} =
               HttpClient.post("#{base_url}/webhook", %{})
    end

    test "handles timeout via opts", %{bypass: bypass, base_url: base_url} do
      Bypass.expect(bypass, "POST", "/webhook", fn conn ->
        Process.sleep(5000)

        conn
        |> Plug.Conn.resp(200, "OK")
      end)

      # Very short timeout should fail
      result = HttpClient.post("#{base_url}/webhook", %{}, timeout: 50)
      assert {:error, _reason} = result

      # Clean up bypass to avoid shutdown errors
      Bypass.pass(bypass)
    end
  end
end

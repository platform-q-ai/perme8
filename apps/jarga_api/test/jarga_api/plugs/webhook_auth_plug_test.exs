defmodule JargaApi.Plugs.WebhookAuthPlugTest do
  use JargaApi.ConnCase, async: true

  alias JargaApi.Plugs.WebhookAuthPlug

  describe "call/2" do
    test "assigns :webhook_signature when X-Webhook-Signature header is present", %{conn: conn} do
      signature = "sha256=abc123hexdigest"

      conn =
        conn
        |> put_req_header("x-webhook-signature", signature)
        |> WebhookAuthPlug.call([])

      assert conn.assigns[:webhook_signature] == signature
      refute conn.halted
    end

    test "halts with 401 when X-Webhook-Signature header is missing", %{conn: conn} do
      conn = WebhookAuthPlug.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Missing webhook signature"}
    end

    test "halts with 401 when X-Webhook-Signature header is empty", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-webhook-signature", "")
        |> WebhookAuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "Missing webhook signature"}
    end
  end
end

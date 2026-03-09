defmodule Agents.Tickets.Infrastructure.Clients.GithubProjectClientTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Infrastructure.Clients.GithubProjectClient

  describe "fetch_sub_issues/3" do
    test "calls the sub-issues endpoint and returns sub-issue numbers" do
      bypass = Bypass.open()

      Bypass.expect_once(
        bypass,
        "GET",
        "/repos/platform-q-ai/perme8/issues/382/sub_issues",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"sub_issues" => [%{"number" => 383}, %{"number" => 384}]})
          )
        end
      )

      assert {:ok, [383, 384]} =
               GithubProjectClient.fetch_sub_issues("platform-q-ai", "perme8", 382,
                 token: "test-token",
                 api_base: "http://localhost:#{bypass.port}"
               )
    end

    test "gracefully returns empty list when fetch fails" do
      bypass = Bypass.open()

      Bypass.expect_once(
        bypass,
        "GET",
        "/repos/platform-q-ai/perme8/issues/500/sub_issues",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(500, Jason.encode!(%{"message" => "boom"}))
        end
      )

      assert {:ok, []} =
               GithubProjectClient.fetch_sub_issues("platform-q-ai", "perme8", 500,
                 token: "test-token",
                 api_base: "http://localhost:#{bypass.port}"
               )
    end
  end
end

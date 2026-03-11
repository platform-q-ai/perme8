defmodule Agents.Tickets.Infrastructure.Clients.GithubProjectClientTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Infrastructure.Clients.GithubProjectClient

  describe "create_issue/2" do
    test "creates a GitHub issue and returns parsed ticket" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/repos/test-org/test-repo/issues", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["title"] == "Fix the login bug"
        assert payload["body"] == "The login form crashes on special chars."
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "number" => 42,
            "title" => "Fix the login bug",
            "body" => "The login form crashes on special chars.",
            "html_url" => "https://github.com/test-org/test-repo/issues/42",
            "state" => "open",
            "labels" => [%{"name" => "bug"}],
            "created_at" => "2026-03-11T00:00:00Z"
          })
        )
      end)

      assert {:ok, issue} =
               GithubProjectClient.create_issue(
                 "Fix the login bug\nThe login form crashes on special chars.",
                 token: "test-token",
                 org: "test-org",
                 repo: "test-repo",
                 api_base: "http://localhost:#{bypass.port}"
               )

      assert issue.number == 42
      assert issue.title == "Fix the login bug"
      assert issue.url == "https://github.com/test-org/test-repo/issues/42"
      assert issue.labels == ["bug"]
    end

    test "single-line body sends empty issue body" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/repos/test-org/test-repo/issues", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["title"] == "Single line title"
        assert payload["body"] == ""

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "number" => 43,
            "title" => "Single line title",
            "body" => "",
            "state" => "open",
            "labels" => []
          })
        )
      end)

      assert {:ok, _issue} =
               GithubProjectClient.create_issue("Single line title",
                 token: "test-token",
                 org: "test-org",
                 repo: "test-repo",
                 api_base: "http://localhost:#{bypass.port}"
               )
    end

    test "returns error on non-2xx response" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/repos/test-org/test-repo/issues", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(%{"message" => "Validation Failed"}))
      end)

      assert {:error, {:unexpected_status, 422, _}} =
               GithubProjectClient.create_issue("Bad issue",
                 token: "test-token",
                 org: "test-org",
                 repo: "test-repo",
                 api_base: "http://localhost:#{bypass.port}"
               )
    end

    test "returns error when token is missing" do
      assert {:error, :missing_token} =
               GithubProjectClient.create_issue("No token",
                 org: "test-org",
                 repo: "test-repo"
               )
    end
  end

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

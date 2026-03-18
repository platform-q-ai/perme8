defmodule Agents.Tickets.Infrastructure.Clients.GithubProjectClientTest do
  use ExUnit.Case, async: true

  import Req.Test

  alias Agents.Tickets.Infrastructure.Clients.GithubProjectClient

  setup :set_req_test_from_context
  setup :verify_on_exit!

  defp client_opts(extra \\ []) do
    Keyword.merge(
      [
        token: "test-token",
        org: "platform-q-ai",
        repo: "perme8",
        req_options: [plug: {Req.Test, __MODULE__}]
      ],
      extra
    )
  end

  describe "get_issue/2" do
    test "returns issue details with comments and sub-issues" do
      stub(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        case {conn.method, conn.request_path} do
          {"GET", "/repos/platform-q-ai/perme8/issues/42"} ->
            json(conn, %{
              "number" => 42,
              "title" => "Implement ticket tool",
              "body" => "Need MCP ticket support",
              "state" => "open",
              "html_url" => "https://github.com/platform-q-ai/perme8/issues/42",
              "created_at" => "2025-01-01T00:00:00Z",
              "labels" => [%{"name" => "enhancement"}],
              "assignees" => [%{"login" => "krisquigley"}]
            })

          {"GET", "/repos/platform-q-ai/perme8/issues/42/comments"} ->
            json(conn, [
              %{
                "id" => 1001,
                "body" => "Looks good",
                "html_url" =>
                  "https://github.com/platform-q-ai/perme8/issues/42#issuecomment-1001",
                "created_at" => "2025-01-01T01:00:00Z"
              }
            ])

          {"GET", "/repos/platform-q-ai/perme8/issues/42/sub_issues"} ->
            json(conn, %{"sub_issues" => [%{"number" => 100}, %{"number" => 101}]})
        end
      end)

      assert {:ok, issue} = GithubProjectClient.get_issue(42, client_opts())
      assert issue.number == 42
      assert issue.title == "Implement ticket tool"
      assert issue.body == "Need MCP ticket support"
      assert issue.state == "open"
      assert issue.labels == ["enhancement"]
      assert issue.assignees == ["krisquigley"]
      assert issue.sub_issue_numbers == [100, 101]
      assert [%{id: 1001, body: "Looks good"}] = issue.comments
    end

    test "returns not_found for missing issue" do
      stub(__MODULE__, fn conn ->
        case {conn.method, conn.request_path} do
          {"GET", "/repos/platform-q-ai/perme8/issues/999"} ->
            conn
            |> Plug.Conn.put_status(404)
            |> json(%{"message" => "Not Found"})
        end
      end)

      assert {:error, :not_found} = GithubProjectClient.get_issue(999, client_opts())
    end

    test "returns missing_token when token is nil" do
      assert {:error, :missing_token} =
               GithubProjectClient.get_issue(1, client_opts(token: nil))
    end
  end

  describe "list_issues/1" do
    test "lists open issues by default" do
      stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues"
        assert conn.query_string =~ "state=open"

        json(conn, [
          %{
            "number" => 1,
            "title" => "Open issue",
            "state" => "open",
            "html_url" => "https://github.com/platform-q-ai/perme8/issues/1",
            "labels" => [%{"name" => "bug"}],
            "assignees" => [%{"login" => "dev1"}]
          }
        ])
      end)

      assert {:ok, [issue]} = GithubProjectClient.list_issues(client_opts())
      assert issue.number == 1
      assert issue.labels == ["bug"]
      assert issue.assignees == ["dev1"]
    end

    test "applies state labels and assignee filters" do
      stub(__MODULE__, fn conn ->
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues"
        assert conn.query_string =~ "state=closed"
        assert conn.query_string =~ "labels=bug%2Curgent"
        assert conn.query_string =~ "assignee=octocat"

        json(conn, [])
      end)

      assert {:ok, []} =
               GithubProjectClient.list_issues(
                 client_opts(state: "closed", labels: ["bug", "urgent"], assignee: "octocat")
               )
    end

    test "uses search API when query is present" do
      stub(__MODULE__, fn conn ->
        assert conn.request_path == "/search/issues"
        assert conn.query_string =~ "q=MCP"
        assert conn.query_string =~ "repo%3Aplatform-q-ai%2Fperme8"

        json(conn, %{
          "items" => [
            %{
              "number" => 15,
              "title" => "MCP support",
              "state" => "open",
              "html_url" => "https://github.com/platform-q-ai/perme8/issues/15",
              "labels" => [],
              "assignees" => []
            }
          ]
        })
      end)

      assert {:ok, [%{number: 15}]} = GithubProjectClient.list_issues(client_opts(query: "MCP"))
    end

    test "returns missing_token when token is nil" do
      assert {:error, :missing_token} = GithubProjectClient.list_issues(client_opts(token: nil))
    end
  end

  describe "create_issue/2" do
    test "creates an issue with title body labels and assignees" do
      stub(__MODULE__, fn conn ->
        assert {conn.method, conn.request_path} == {"POST", "/repos/platform-q-ai/perme8/issues"}

        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["title"] == "Create issue"
        assert payload["body"] == "Issue body"
        assert payload["labels"] == ["enhancement"]
        assert payload["assignees"] == ["dev1"]

        conn
        |> Plug.Conn.put_status(201)
        |> json(%{
          "number" => 50,
          "title" => "Create issue",
          "html_url" => "https://github.com/platform-q-ai/perme8/issues/50"
        })
      end)

      assert {:ok, issue} =
               GithubProjectClient.create_issue(
                 %{
                   "title" => "Create issue",
                   "body" => "Issue body",
                   "labels" => ["enhancement"],
                   "assignees" => ["dev1"]
                 },
                 client_opts()
               )

      assert issue.number == 50
      assert issue.title == "Create issue"
    end

    test "returns missing_token when token is nil" do
      assert {:error, :missing_token} =
               GithubProjectClient.create_issue(%{"title" => "x"}, client_opts(token: nil))
    end
  end

  describe "update_issue/3" do
    test "updates issue fields and omits nil values" do
      stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/60"

        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["title"] == "Updated"
        assert payload["labels"] == []
        refute Map.has_key?(payload, "body")

        json(conn, %{
          "number" => 60,
          "title" => "Updated",
          "body" => "unchanged",
          "state" => "open",
          "html_url" => "https://github.com/platform-q-ai/perme8/issues/60",
          "labels" => [],
          "assignees" => []
        })
      end)

      assert {:ok, issue} =
               GithubProjectClient.update_issue(
                 60,
                 %{"title" => "Updated", "body" => nil, "labels" => []},
                 client_opts()
               )

      assert issue.title == "Updated"
      assert issue.labels == []
    end

    test "returns not_found for missing issue" do
      stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> json(%{"message" => "Not Found"})
      end)

      assert {:error, :not_found} =
               GithubProjectClient.update_issue(999, %{"title" => "Nope"}, client_opts())
    end
  end

  describe "close_issue_with_comment/2" do
    test "adds comment then closes issue" do
      expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/80/comments"
        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["body"] == "Closing this"
        conn |> Plug.Conn.put_status(201) |> json(%{"id" => 12})
      end)

      expect(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/80"
        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["state"] == "closed"

        json(conn, %{
          "number" => 80,
          "title" => "Close me",
          "state" => "closed",
          "body" => nil,
          "html_url" => "https://github.com/platform-q-ai/perme8/issues/80",
          "labels" => [],
          "assignees" => []
        })
      end)

      assert {:ok, %{state: "closed"}} =
               GithubProjectClient.close_issue_with_comment(
                 80,
                 Keyword.put(client_opts(), :comment, "Closing this")
               )
    end

    test "returns not_found when issue does not exist" do
      stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> json(%{"message" => "Not Found"})
      end)

      assert {:error, :not_found} =
               GithubProjectClient.close_issue_with_comment(999, client_opts())
    end
  end

  describe "add_comment/3" do
    test "posts comment and returns parsed map" do
      stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/81/comments"
        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["body"] == "Looks great"

        conn
        |> Plug.Conn.put_status(201)
        |> json(%{
          "id" => 44,
          "body" => "Looks great",
          "html_url" => "https://github.com/platform-q-ai/perme8/issues/81#issuecomment-44",
          "created_at" => "2025-01-01T00:00:00Z"
        })
      end)

      assert {:ok, comment} = GithubProjectClient.add_comment(81, "Looks great", client_opts())
      assert comment.id == 44
      assert comment.body == "Looks great"
    end

    test "returns not_found when issue does not exist" do
      stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> json(%{"message" => "Not Found"})
      end)

      assert {:error, :not_found} = GithubProjectClient.add_comment(999, "x", client_opts())
    end
  end

  describe "add_sub_issue/3" do
    test "links child issue to parent" do
      expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/11"

        json(conn, %{"node_id" => "I_kwDOA", "number" => 11})
      end)

      expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/10/sub_issues"

        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["sub_issue_id"] == "I_kwDOA"
        json(conn, %{})
      end)

      assert {:ok, %{parent_number: 10, child_number: 11}} =
               GithubProjectClient.add_sub_issue(10, 11, client_opts())
    end

    test "returns descriptive error on unsupported API" do
      expect(__MODULE__, fn conn ->
        json(conn, %{"node_id" => "I_kwDOA", "number" => 11})
      end)

      expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> json(%{"message" => "Sub-issues are not enabled"})
      end)

      assert {:error, message} = GithubProjectClient.add_sub_issue(10, 11, client_opts())
      assert is_binary(message)
      assert message =~ "sub-issue"
    end
  end

  describe "remove_sub_issue/3" do
    test "unlinks child issue from parent" do
      expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/11"

        json(conn, %{"node_id" => "I_kwDOA", "number" => 11})
      end)

      expect(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/repos/platform-q-ai/perme8/issues/10/sub_issues"

        payload = conn |> raw_body() |> Jason.decode!()
        assert payload["sub_issue_id"] == "I_kwDOA"
        conn |> Plug.Conn.put_status(204) |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{parent_number: 10, child_number: 11}} =
               GithubProjectClient.remove_sub_issue(10, 11, client_opts())
    end

    test "returns descriptive error on unsupported API" do
      expect(__MODULE__, fn conn ->
        json(conn, %{"node_id" => "I_kwDOA", "number" => 11})
      end)

      expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> json(%{"message" => "Not Found"})
      end)

      assert {:error, message} = GithubProjectClient.remove_sub_issue(10, 11, client_opts())
      assert is_binary(message)
      assert message =~ "sub-issue"
    end
  end

  describe "behaviour contract" do
    test "implements GithubTicketClientBehaviour callbacks" do
      Code.ensure_loaded!(GithubProjectClient)
      assert function_exported?(GithubProjectClient, :get_issue, 2)
      assert function_exported?(GithubProjectClient, :list_issues, 1)
      assert function_exported?(GithubProjectClient, :create_issue, 2)
      assert function_exported?(GithubProjectClient, :update_issue, 3)
      assert function_exported?(GithubProjectClient, :close_issue_with_comment, 2)
      assert function_exported?(GithubProjectClient, :add_comment, 3)
      assert function_exported?(GithubProjectClient, :add_sub_issue, 3)
      assert function_exported?(GithubProjectClient, :remove_sub_issue, 3)
    end
  end

  describe "fetch_tickets/1" do
    test "keeps tickets when sub-issue enrichment times out" do
      # Simulate two issues: one whose sub-issue call succeeds,
      # one whose sub-issue call hangs long enough to be killed by Task.async_stream.
      # Both tickets must appear in the result.
      stub(__MODULE__, fn conn ->
        case {conn.method, conn.request_path} do
          {"GET", "/repos/platform-q-ai/perme8/issues"} ->
            json(conn, [
              %{
                "number" => 700,
                "title" => "Fast ticket",
                "state" => "open",
                "html_url" => "https://github.com/platform-q-ai/perme8/issues/700",
                "labels" => [],
                "assignees" => [],
                "created_at" => "2025-01-01T00:00:00Z"
              },
              %{
                "number" => 701,
                "title" => "Slow ticket",
                "state" => "open",
                "html_url" => "https://github.com/platform-q-ai/perme8/issues/701",
                "labels" => [],
                "assignees" => [],
                "created_at" => "2025-01-01T00:00:00Z"
              }
            ])

          {"GET", "/repos/platform-q-ai/perme8/issues/700/sub_issues"} ->
            json(conn, [])

          {"GET", "/repos/platform-q-ai/perme8/issues/701/sub_issues"} ->
            # Simulate a timeout by sleeping longer than the task timeout
            Process.sleep(20_000)
            json(conn, [])
        end
      end)

      # Use a very short timeout to trigger the :kill_task on issue 701
      assert {:ok, tickets} =
               GithubProjectClient.fetch_tickets(client_opts(enrichment_timeout: 100))

      numbers = Enum.map(tickets, & &1.number) |> Enum.sort()

      assert numbers == [700, 701],
             "Both tickets must be returned even when sub-issue call times out"

      # The timed-out ticket should have empty sub_issue_numbers
      slow_ticket = Enum.find(tickets, &(&1.number == 701))
      assert slow_ticket.sub_issue_numbers == []
    end
  end

  describe "fetch_sub_issues/4" do
    test "calls the sub-issues endpoint and returns sub-issue numbers" do
      stub(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        json(conn, %{"sub_issues" => [%{"number" => 383}, %{"number" => 384}]})
      end)

      assert {:ok, [383, 384]} =
               GithubProjectClient.fetch_sub_issues("platform-q-ai", "perme8", 382,
                 token: "test-token",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "gracefully returns empty list when fetch fails" do
      stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> json(%{"message" => "boom"})
      end)

      assert {:ok, []} =
               GithubProjectClient.fetch_sub_issues("platform-q-ai", "perme8", 500,
                 token: "test-token",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end
  end
end

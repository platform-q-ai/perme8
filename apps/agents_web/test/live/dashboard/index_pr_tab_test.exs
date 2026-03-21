defmodule AgentsWeb.DashboardLive.IndexPrTabTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  alias Agents.Pipeline
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

  describe "PR tab" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows PR tab only when selected ticket has linked PR", %{conn: conn, user: user} do
      setup_ticket_session(user, 506, "Session with linked PR")
      setup_ticket_session(user, 507, "Session without linked PR")

      {:ok, _pr} =
        Pipeline.create_pull_request(%{
          source_branch: "HEAD",
          target_branch: "HEAD",
          title: "Linked PR",
          body: "PR body",
          status: "in_review",
          linked_ticket: 506
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="506"]))
      |> render_click()

      assert has_element?(lv, ~s([role="tab"][data-tab-id="pr"]))

      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="507"]))
      |> render_click()

      refute has_element?(lv, ~s([role="tab"][data-tab-id="pr"]))
    end

    test "supports ?tab=pr only when linked PR exists", %{conn: conn, user: user} do
      setup_ticket_session(user, 506, "Session with linked PR")

      {:ok, _pr} =
        Pipeline.create_pull_request(%{
          source_branch: "HEAD",
          target_branch: "HEAD",
          title: "Linked PR",
          body: "PR body",
          status: "in_review",
          linked_ticket: 506
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?tab=pr")
      assert has_element?(lv, ~s([role="tab"][data-tab-id="pr"][aria-selected="true"]))

      setup_ticket_session(user, 507, "Session without linked PR")
      {:ok, lv_without_pr, _html} = live(conn, ~p"/sessions?ticket=507&tab=pr")

      assert has_element?(
               lv_without_pr,
               ~s([role="tab"][data-tab-id="chat"][aria-selected="true"])
             )

      refute has_element?(lv_without_pr, ~s([role="tab"][data-tab-id="pr"]))
    end

    test "renders PR header, diff, threads and excludes pipeline status", %{
      conn: conn,
      user: user
    } do
      setup_ticket_session(user, 506, "Session with linked PR")

      {:ok, pr} =
        Pipeline.create_pull_request(%{
          source_branch: "HEAD",
          target_branch: "HEAD",
          title: "Linked PR",
          body: "# Description\n\nBody",
          status: "in_review",
          linked_ticket: 506
        })

      {:ok, _} =
        Pipeline.comment_on_pull_request(pr.number, %{
          actor_id: "reviewer-1",
          body: "Please extract helper",
          path: "lib/demo.ex",
          line: 12
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?tab=pr")

      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-title"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-status"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-branches"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-author-and-timestamps"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-description"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-diff-file"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-diff-code"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-review-thread"]))
      assert has_element?(lv, ~s(#tabpanel-pr [data-testid="pr-thread-resolved-state"]))

      refute has_element?(lv, ~s(#tabpanel-pr [data-testid="pipeline-status"]))
      refute has_element?(lv, ~s(#tabpanel-pr [data-testid="pipeline-stage-widget"]))
    end

    test "supports comment reply resolve and review actions", %{conn: conn, user: user} do
      setup_ticket_session(user, 506, "Session with linked PR")

      {:ok, pr} =
        Pipeline.create_pull_request(%{
          source_branch: "HEAD",
          target_branch: "HEAD",
          title: "Linked PR",
          body: "Body",
          status: "in_review",
          linked_ticket: 506
        })

      {:ok, with_comment} =
        Pipeline.comment_on_pull_request(pr.number, %{
          actor_id: "reviewer-1",
          body: "Initial thread",
          path: "lib/demo.ex",
          line: 22
        })

      root = hd(with_comment.comments)

      {:ok, lv, _html} = live(conn, ~p"/sessions?tab=pr")

      lv
      |> element(~s(#tabpanel-pr [data-testid="pr-add-inline-comment-button"]))
      |> render_click()

      lv
      |> form("#pr-inline-comment-form", %{
        "comment" => %{"body" => "Please extract this logic into a helper."}
      })
      |> render_submit()

      assert render(lv) =~ "Please extract this logic into a helper."

      lv
      |> form(~s(#pr-reply-form-#{root.id}), %{
        "reply" => %{"body" => "Good point, I will update this."}
      })
      |> render_submit()

      assert render(lv) =~ "Good point, I will update this."

      lv
      |> element(~s([data-testid="pr-resolve-thread-button"][phx-value-comment-id="#{root.id}"]))
      |> render_click()

      html = render(lv)
      assert html =~ "resolved"

      lv
      |> element(~s(#tabpanel-pr [data-testid="pr-review-decision-approve"]))
      |> render_click()

      lv
      |> form("#pr-submit-review-form", %{"review" => %{"body" => "Ship it"}})
      |> render_submit()

      assert render(lv) =~ "Approved"
    end
  end

  defp setup_ticket_session(user, ticket_number, instruction) do
    task_fixture(%{
      user_id: user.id,
      instruction: "#{instruction} for ##{ticket_number}",
      container_id: "container-#{ticket_number}",
      status: "completed"
    })

    {:ok, _ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: ticket_number,
        title: "Ticket #{ticket_number}",
        body: "Ticket body",
        status: "Ready",
        priority: "Need",
        size: "M",
        labels: []
      })

    :ok
  end
end

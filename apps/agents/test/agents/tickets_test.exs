defmodule Agents.TicketsTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Tickets
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  defmodule SuccessGithubClient do
    @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

    @impl true
    def update_issue(number, _attrs, _opts),
      do: {:ok, %{number: number, state: "closed"}}

    @impl true
    def get_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def list_issues(_), do: {:error, :not_implemented}
    @impl true
    def create_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def close_issue_with_comment(_, _), do: {:error, :not_implemented}
    @impl true
    def add_comment(_, _, _), do: {:error, :not_implemented}
    @impl true
    def add_sub_issue(_, _, _), do: {:error, :not_implemented}
    @impl true
    def remove_sub_issue(_, _, _), do: {:error, :not_implemented}
  end

  defmodule NotFoundGithubClient do
    @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

    @impl true
    def update_issue(_number, _attrs, _opts),
      do: {:error, :not_found}

    @impl true
    def get_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def list_issues(_), do: {:error, :not_implemented}
    @impl true
    def create_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def close_issue_with_comment(_, _), do: {:error, :not_implemented}
    @impl true
    def add_comment(_, _, _), do: {:error, :not_implemented}
    @impl true
    def add_sub_issue(_, _, _), do: {:error, :not_implemented}
    @impl true
    def remove_sub_issue(_, _, _), do: {:error, :not_implemented}
  end

  defmodule FailingGithubClient do
    @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

    @impl true
    def update_issue(_number, _attrs, _opts),
      do: {:error, {:unexpected_status, 502, "Bad Gateway"}}

    @impl true
    def get_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def list_issues(_), do: {:error, :not_implemented}
    @impl true
    def create_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def close_issue_with_comment(_, _), do: {:error, :not_implemented}
    @impl true
    def add_comment(_, _, _), do: {:error, :not_implemented}
    @impl true
    def add_sub_issue(_, _, _), do: {:error, :not_implemented}
    @impl true
    def remove_sub_issue(_, _, _), do: {:error, :not_implemented}
  end

  defp create_ticket!(number, attrs \\ %{}) do
    base = %{
      number: number,
      title: "Ticket #{number}",
      created_at: ~U[2026-03-11 09:00:00Z],
      labels: []
    }

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  describe "record_ticket_stage_transition/3" do
    test "records transition and returns updated ticket and lifecycle event" do
      ticket = create_ticket!(402)
      now = ~U[2026-03-11 12:00:00Z]

      assert {:ok, %{ticket: updated_ticket, lifecycle_event: lifecycle_event}} =
               Tickets.record_ticket_stage_transition(ticket.id, "ready",
                 trigger: "manual",
                 now: now
               )

      assert updated_ticket.lifecycle_stage == "ready"
      assert lifecycle_event.ticket_id == ticket.id
      assert lifecycle_event.from_stage == "open"
      assert lifecycle_event.to_stage == "ready"
      assert lifecycle_event.trigger == "manual"
    end
  end

  describe "get_ticket_lifecycle/1" do
    test "returns ticket with preloaded lifecycle events" do
      ticket = create_ticket!(403)

      assert {:ok, _} =
               Tickets.record_ticket_stage_transition(ticket.id, "in_progress",
                 trigger: "sync",
                 now: ~U[2026-03-11 13:00:00Z]
               )

      assert {:ok, lifecycle_ticket} = Tickets.get_ticket_lifecycle(ticket.id)
      assert lifecycle_ticket.id == ticket.id
      assert lifecycle_ticket.lifecycle_stage == "in_progress"
      assert length(lifecycle_ticket.lifecycle_events) == 1
      assert hd(lifecycle_ticket.lifecycle_events).to_stage == "in_progress"
    end
  end

  describe "list_project_tickets/2" do
    test "returns lifecycle fields on mapped ticket entities" do
      create_ticket!(404, %{
        lifecycle_stage: "closed",
        lifecycle_stage_entered_at: ~U[2026-03-11 14:00:00Z],
        state: "closed"
      })

      [ticket] =
        Tickets.list_project_tickets("user-id",
          tasks: [],
          tickets: ProjectTicketRepository.list_all()
        )

      assert ticket.lifecycle_stage == "closed"
      assert ticket.lifecycle_stage_entered_at == ~U[2026-03-11 14:00:00Z]
      assert ticket.lifecycle_events == []
    end
  end

  describe "close_project_ticket/2" do
    test "closes on GitHub first, then marks as closed locally" do
      create_ticket!(700, %{state: "open"})

      assert :ok = Tickets.close_project_ticket(700, github_client: SuccessGithubClient)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 700)
      assert refreshed.state == "closed"
    end

    test "returns error and does not close locally when GitHub fails" do
      create_ticket!(701, %{state: "open"})

      assert {:error, {:unexpected_status, 502, "Bad Gateway"}} =
               Tickets.close_project_ticket(701, github_client: FailingGithubClient)

      # Ticket must remain open locally
      refreshed = Repo.get_by!(ProjectTicketSchema, number: 701)
      assert refreshed.state == "open"
    end

    test "succeeds even when ticket does not exist locally (GitHub already closed)" do
      assert :ok = Tickets.close_project_ticket(9999, github_client: SuccessGithubClient)
    end
  end

  describe "update_ticket_labels/3" do
    test "updates labels on GitHub first, then persists locally" do
      create_ticket!(750, %{labels: ["old-label"]})

      assert :ok =
               Tickets.update_ticket_labels(750, ["bug", "agents"],
                 github_client: SuccessGithubClient
               )

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 750)
      assert refreshed.labels == ["bug", "agents"]
    end

    test "still updates locally when GitHub returns :not_found (issue deleted)" do
      create_ticket!(751, %{labels: ["old"]})

      assert :ok =
               Tickets.update_ticket_labels(751, ["new"], github_client: NotFoundGithubClient)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 751)
      assert refreshed.labels == ["new"]
    end

    test "returns error and does NOT update locally when GitHub fails" do
      create_ticket!(752, %{labels: ["original"]})

      assert {:error, {:unexpected_status, 502, "Bad Gateway"}} =
               Tickets.update_ticket_labels(752, ["new"], github_client: FailingGithubClient)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 752)
      assert refreshed.labels == ["original"]
    end

    test "can set labels to empty list" do
      create_ticket!(753, %{labels: ["bug", "frontend"]})

      assert :ok =
               Tickets.update_ticket_labels(753, [], github_client: SuccessGithubClient)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 753)
      assert refreshed.labels == []
    end
  end
end

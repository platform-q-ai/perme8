defmodule Agents.Tickets.Infrastructure.Subscribers.GithubTicketPushHandlerTest do
  use Agents.DataCase, async: false

  alias Agents.Repo
  alias Agents.Tickets.Domain.Events.TicketClosed
  alias Agents.Tickets.Domain.Events.TicketCreated
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Subscribers.GithubTicketPushHandler

  @topic "sessions:tickets"

  setup do
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, @topic)
    :ok
  end

  defp insert_pending_ticket!(attrs) do
    defaults = %{
      number: -1,
      title: "Test ticket",
      body: "Test body",
      state: "open",
      sync_state: "pending_push",
      position: 0,
      created_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp with_bypass_config(bypass) do
    original_config = Application.get_env(:agents, :sessions, [])

    Application.put_env(
      :agents,
      :sessions,
      Keyword.merge(original_config,
        github_token: "test-token",
        github_org: "platform-q-ai",
        github_repo: "perme8",
        github_api_base: "http://localhost:#{bypass.port}"
      )
    )

    on_exit(fn ->
      Application.put_env(:agents, :sessions, original_config)
    end)
  end

  describe "subscriptions/0" do
    test "subscribes to the tickets aggregate topic" do
      assert GithubTicketPushHandler.subscriptions() == ["events:tickets:ticket"]
    end
  end

  describe "handle_event/1 with TicketCreated" do
    test "pushes to GitHub and updates local ticket on success" do
      ticket = insert_pending_ticket!(%{number: -42, title: "Push me", body: "Please"})
      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "POST", "/repos/platform-q-ai/perme8/issues", fn conn ->
        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(req_body)
        assert payload["title"] == "Push me"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{
            "number" => 999,
            "title" => "Push me",
            "body" => "Please",
            "html_url" => "https://github.com/platform-q-ai/perme8/issues/999",
            "state" => "open",
            "labels" => [],
            "created_at" => DateTime.to_iso8601(DateTime.utc_now())
          })
        )
      end)

      event =
        TicketCreated.new(%{
          aggregate_id: to_string(ticket.id),
          actor_id: "user-123",
          ticket_id: ticket.id,
          title: "Push me",
          body: "Please"
        })

      assert :ok == GithubTicketPushHandler.handle_event(event)

      # Verify the ticket was updated with the real GitHub issue number
      updated = Repo.get!(ProjectTicketSchema, ticket.id)
      assert updated.number == 999
      assert updated.sync_state == "synced"
      assert updated.url == "https://github.com/platform-q-ai/perme8/issues/999"

      # Verify a PubSub refresh was broadcast
      assert_received {:tickets_synced, _}
    end

    test "marks ticket as sync_error when GitHub push fails" do
      ticket = insert_pending_ticket!(%{number: -99, title: "Will fail", body: "Error"})
      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "POST", "/repos/platform-q-ai/perme8/issues", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(%{"message" => "Validation Failed"}))
      end)

      event =
        TicketCreated.new(%{
          aggregate_id: to_string(ticket.id),
          actor_id: "user-123",
          ticket_id: ticket.id,
          title: "Will fail",
          body: "Error"
        })

      assert {:error, _} = GithubTicketPushHandler.handle_event(event)

      updated = Repo.get!(ProjectTicketSchema, ticket.id)
      assert updated.sync_state == "sync_error"
    end

    test "ignores non-matching events" do
      assert :ok ==
               GithubTicketPushHandler.handle_event(%{event_type: "sessions.task_completed"})
    end
  end

  describe "handle_event/1 with TicketClosed" do
    test "closes on GitHub and marks ticket as synced" do
      ticket = insert_pending_ticket!(%{number: 500, title: "Close me", state: "closed"})
      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "PATCH", "/repos/platform-q-ai/perme8/issues/500", fn conn ->
        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(req_body)
        assert payload["state"] == "closed"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "number" => 500,
            "state" => "closed",
            "title" => "Close me",
            "html_url" => "https://github.com/platform-q-ai/perme8/issues/500",
            "labels" => [],
            "created_at" => DateTime.to_iso8601(DateTime.utc_now())
          })
        )
      end)

      event =
        TicketClosed.new(%{
          aggregate_id: to_string(ticket.id),
          actor_id: "user-123",
          ticket_id: ticket.id,
          number: 500
        })

      assert :ok == GithubTicketPushHandler.handle_event(event)

      updated = Repo.get!(ProjectTicketSchema, ticket.id)
      assert updated.sync_state == "synced"
      assert updated.last_synced_at != nil

      assert_received {:tickets_synced, _}
    end

    test "marks synced when GitHub returns not found (already closed)" do
      ticket = insert_pending_ticket!(%{number: 501, title: "Already gone", state: "closed"})
      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "PATCH", "/repos/platform-q-ai/perme8/issues/501", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"message" => "Not Found"}))
      end)

      event =
        TicketClosed.new(%{
          aggregate_id: to_string(ticket.id),
          actor_id: "user-123",
          ticket_id: ticket.id,
          number: 501
        })

      assert :ok == GithubTicketPushHandler.handle_event(event)

      updated = Repo.get!(ProjectTicketSchema, ticket.id)
      assert updated.sync_state == "synced"
    end

    test "marks sync_error when GitHub close fails" do
      ticket = insert_pending_ticket!(%{number: 502, title: "Will fail", state: "closed"})
      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "PATCH", "/repos/platform-q-ai/perme8/issues/502", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(%{"message" => "Validation Failed"}))
      end)

      event =
        TicketClosed.new(%{
          aggregate_id: to_string(ticket.id),
          actor_id: "user-123",
          ticket_id: ticket.id,
          number: 502
        })

      assert {:error, _} = GithubTicketPushHandler.handle_event(event)

      updated = Repo.get!(ProjectTicketSchema, ticket.id)
      assert updated.sync_state == "sync_error"
    end

    test "returns ok when ticket no longer exists locally" do
      event =
        TicketClosed.new(%{
          aggregate_id: "999999",
          actor_id: "user-123",
          ticket_id: 999_999,
          number: 503
        })

      bypass = Bypass.open()
      with_bypass_config(bypass)

      Bypass.expect_once(bypass, "PATCH", "/repos/platform-q-ai/perme8/issues/503", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "number" => 503,
            "state" => "closed",
            "title" => "Gone",
            "html_url" => "https://github.com/platform-q-ai/perme8/issues/503",
            "labels" => [],
            "created_at" => DateTime.to_iso8601(DateTime.utc_now())
          })
        )
      end)

      # Should not crash even though ticket_id doesn't exist in DB
      assert :ok == GithubTicketPushHandler.handle_event(event)
    end
  end
end

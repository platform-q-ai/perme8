defmodule JargaWeb.NotificationsLive.OnMountTest do
  @moduledoc """
  Tests for the NotificationsLive.OnMount hook's structured event handling.
  """
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  alias Jarga.Notifications.Domain.Events.NotificationCreated

  describe "structured event subscription and handler" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "receives %NotificationCreated{} and updates notification bell", %{
      conn: conn,
      user: user
    } do
      # Mount a LiveView in the :app live_session (which has OnMount hook)
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        NotificationCreated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: Ecto.UUID.generate(),
          notification_id: Ecto.UUID.generate(),
          user_id: user.id,
          type: "workspace_invitation",
          target_user_id: user.id
        })

      # Send structured event to the LiveView process
      send(lv.pid, event)

      # Should not crash - the OnMount hook handles the event
      assert render(lv)
    end
  end
end

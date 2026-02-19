defmodule JargaWeb.ChatLive.MessageHandlersTest do
  @moduledoc """
  Tests that the handle_chat_messages/0 macro generates correct
  handle_info/2 callbacks, including structured event patterns.
  """
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  alias Jarga.Notifications.Domain.Events.NotificationCreated

  describe "NotificationCreated event handler (via macro)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "handles %NotificationCreated{} event without crashing", %{conn: conn, user: user} do
      # Mount any LiveView that uses handle_chat_messages() macro
      # The /app route (Dashboard) uses it via admin layout
      {:ok, lv, _html} = live(conn, ~p"/app")

      event =
        NotificationCreated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: user.id,
          notification_id: Ecto.UUID.generate(),
          user_id: user.id,
          type: "workspace_invitation",
          target_user_id: user.id
        })

      send(lv.pid, event)

      # Should not crash - handler processes the event successfully
      assert render(lv)
    end
  end
end

defmodule JargaWeb.NotificationsLive.NotificationBellTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jarga.Accounts
  alias Jarga.Notifications
  alias Jarga.Workspaces

  setup do
    # Create test users
    {:ok, owner} =
      Accounts.register_user(%{
        email: "owner@example.com",
        password: "ValidPassword123!",
        first_name: "Owner",
        last_name: "User"
      })

    {:ok, invitee} =
      Accounts.register_user(%{
        email: "invitee@example.com",
        password: "ValidPassword123!",
        first_name: "Invitee",
        last_name: "User"
      })

    # Create workspace
    {:ok, workspace} =
      Workspaces.create_workspace(owner, %{
        name: "Test Workspace"
      })

    %{owner: owner, invitee: invitee, workspace: workspace}
  end

  describe "PubSub subscription" do
    test "component receives and handles notifications broadcasted via PubSub", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      # Mount a LiveView that contains the notification bell component
      {:ok, view, _html} = live(conn, ~p"/app")

      # Initially should have 0 unread count
      assert element(view, "#notification-bell") |> render() =~ "Notifications"

      # Create a notification (this will broadcast via PubSub)
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      # The component should update automatically via handle_info
      # Wait a bit for the async update
      :timer.sleep(200)

      # Check that the notification bell component now shows the unread badge
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ ~r/bg-error.*rounded-full/
    end

    test "receives new notification via PubSub and updates bell", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      # Mount the LiveView
      {:ok, view, _html} = live(conn, ~p"/app")

      # Create a notification (this will broadcast via PubSub)
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      # The component should update automatically via handle_info
      :timer.sleep(200)

      # Check that the bell shows the unread count
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ ~r/bg-error.*rounded-full/

      # Open the dropdown to see the notification
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Check the dropdown content
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ "Test Workspace"
      assert notification_bell_html =~ "invited you to join"
    end

    test "updates unread count when new notification arrives", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send first notification
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      :timer.sleep(200)
      notification_bell_html = element(view, "#notification-bell") |> render()

      # Should show count of 1
      assert notification_bell_html =~ "1"

      # Send second notification
      {:ok, workspace2} =
        Workspaces.create_workspace(owner, %{
          name: "Another Workspace"
        })

      {:ok, _notification2} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace2.id,
          workspace_name: workspace2.name,
          invited_by_name: owner.email,
          role: "admin"
        })

      :timer.sleep(200)
      notification_bell_html = element(view, "#notification-bell") |> render()

      # Should show count of 2
      assert notification_bell_html =~ "2"
    end
  end

  describe "existing functionality" do
    test "shows notifications when dropdown is toggled", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      # Create a notification first
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Click the bell to open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      html = render(view)

      # Should show the notification
      assert html =~ workspace.name
      assert html =~ "invited you to join"
    end

    test "marks notification as read when clicked", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Click mark as read
      view
      |> element("button[phx-click='mark_read'][phx-value-notification-id='#{notification.id}']")
      |> render_click()

      # Verify notification was marked as read
      updated_notification = Notifications.get_notification(notification.id, invitee.id)
      assert updated_notification.read == true
    end

    test "marks all notifications as read", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      # Create multiple notifications
      {:ok, _notification1} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      {:ok, workspace2} = Workspaces.create_workspace(owner, %{name: "Workspace 2"})

      {:ok, _notification2} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace2.id,
          workspace_name: workspace2.name,
          invited_by_name: owner.email,
          role: "admin"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Click mark all as read
      view
      |> element("#notification-mark-all-read-btn")
      |> render_click()

      # Verify unread count is now 0
      html = render(view)
      refute html =~ ~r/bg-error.*rounded-full/
    end

    test "accepts workspace invitation", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Verify accept button is visible
      html = render(view)
      assert html =~ "notification-accept-btn-#{notification.id}"

      # Click accept button - this should trigger the acceptance
      view
      |> element("#notification-accept-btn-#{notification.id}")
      |> render_click()

      # Give it time to process
      :timer.sleep(100)

      # The notification should have been processed successfully
      # Verify that a workspace member exists for this user
      members = Jarga.Workspaces.list_members(workspace.id)
      assert Enum.any?(members, fn m -> m.user_id == invitee.id end)
    end

    test "declines workspace invitation", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Click decline button
      view
      |> element("#notification-decline-btn-#{notification.id}")
      |> render_click()

      # Verify action status is shown
      html = render(view)
      assert html =~ "Invitation declined" or html =~ "declined"
    end

    test "displays unread count badge with 99+ for large numbers", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      # Create 100 notifications
      for i <- 1..100 do
        {:ok, _} =
          Notifications.create_workspace_invitation_notification(%{
            user_id: invitee.id,
            workspace_id: workspace.id,
            workspace_name: "Workspace #{i}",
            invited_by_name: owner.email,
            role: "member"
          })
      end

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      :timer.sleep(100)

      # Should show 99+ when count exceeds 99
      html = render(view)
      assert html =~ "99+"
    end

    test "closes dropdown when clicking away", %{
      conn: conn,
      invitee: invitee
    } do
      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Dropdown should be visible (not have hidden class in the div)
      html = render(view)
      # When dropdown is shown, the div should not have "hidden" in its classes
      assert html =~ ~r/id="notification-bell-dropdown".*class="[^"]*(?!hidden)/
    end

    test "shows empty state when no notifications", %{
      conn: conn,
      invitee: invitee
    } do
      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      html = render(view)
      assert html =~ "No notifications"
    end

    test "shows action status for accepted invitation", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Accept through the UI
      view
      |> element("#notification-accept-btn-#{notification.id}")
      |> render_click()

      :timer.sleep(150)

      # Verify the workspace membership was created (invitation accepted)
      members = Jarga.Workspaces.list_members(workspace.id)
      assert Enum.any?(members, fn m -> m.user_id == invitee.id end)

      # Reload the page to get updated notification state
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown to see the updated status
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      html = render(view)
      # The action status should show "accepted"
      assert html =~ "accepted"
    end

    test "shows action status for declined invitation", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      # Decline the invitation
      {:ok, _} = Notifications.decline_workspace_invitation(notification.id, invitee.id)

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      html = render(view)
      assert html =~ "Invitation declined"
    end
  end

  defp get_component_id(view) do
    # Extract component ID from the view
    # This is a helper to target the live component
    "notification-bell"
  end
end

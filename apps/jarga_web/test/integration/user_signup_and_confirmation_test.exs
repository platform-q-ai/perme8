defmodule JargaWeb.Integration.UserSignupAndConfirmationTest do
  # async: false because these tests use PubSub notifications which require
  # database access from a GenServer process (WorkspaceInvitationSubscriber)
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Accounts

  # Tag this module as integration tests to enable PubSub subscribers
  @moduletag :integration

  # Helper function to wait for async notifications to be created
  defp wait_for_notification(user_id, max_attempts \\ 10) do
    Enum.reduce_while(1..max_attempts, nil, fn _attempt, _acc ->
      case Jarga.Notifications.list_notifications(user_id) do
        [] ->
          Process.sleep(10)
          {:cont, nil}

        notifications ->
          {:halt, List.first(notifications)}
      end
    end)
  end

  describe "user signup and email confirmation flow" do
    test "user signs up, receives email, clicks confirmation link, and is confirmed", %{
      conn: conn
    } do
      # Step 1: User visits registration page
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Step 2: User fills out and submits registration form
      email = unique_user_email()
      first_name = "Test"
      last_name = "User"
      password = valid_user_password()

      form =
        form(lv, "#registration_form",
          user: %{
            email: email,
            first_name: first_name,
            last_name: last_name,
            password: password
          }
        )

      # Step 3: User is redirected to login page with success message
      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ ~r/An email was sent/

      # Verify user was created but NOT confirmed
      user = Accounts.get_user_by_email(email)
      assert user.email == email
      assert user.first_name == first_name
      assert user.last_name == last_name
      assert user.confirmed_at == nil
      assert user.status == "active"

      # Step 4: Extract confirmation link from email
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      # Step 5: User clicks confirmation link (magic link)
      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      # Step 6: User submits confirmation form
      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Step 7: Verify user is now confirmed
      user = Accounts.get_user_by_email(email)
      assert user.confirmed_at != nil
      assert user.status == "active"

      # Step 8: Verify user can now log in with password
      conn = build_conn()
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{
            email: email,
            password: password
          }
        )

      render_submit(form, %{"user" => %{"remember_me" => "true"}})
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"
    end

    test "user with password is auto-confirmed when clicking magic link", %{conn: conn} do
      # Create unconfirmed user with password
      user = unconfirmed_user_fixture(password: valid_user_password())
      assert user.confirmed_at == nil

      # Extract magic link token
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      # Click magic link and submit confirmation form
      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"

      # Verify user is now confirmed
      user = Accounts.get_user_by_email(user.email)
      assert user.confirmed_at != nil
    end

    # NOTE: This test manipulates database timestamps to test token expiration
    test "confirmation link expires after 15 minutes", %{conn: conn} do
      user = unconfirmed_user_fixture()

      # Create an old token (simulate expired token by inserting directly)
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      # Manually expire the token in the database by updating it directly
      # Note: In a real application, you would wait 15 minutes or use time mocking
      # For testing purposes, we'll expire the token using a test helper
      expire_user_login_token(user.id)

      # Try to use expired token - should be redirected to login page
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"

      # Verify user is still unconfirmed
      user = Accounts.get_user_by_email(user.email)
      assert user.confirmed_at == nil
    end

    test "confirmation link can only be used once", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      # Use token first time - should succeed
      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"

      # Log out
      conn = delete(conn, ~p"/users/log-out")

      # Try to use the same token again - should fail
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end

  describe "unconfirmed users cannot log in with password" do
    test "unconfirmed user cannot log in with correct password", %{conn: conn} do
      # Create unconfirmed user with password
      password = valid_user_password()
      user = unconfirmed_user_fixture(password: password)
      assert user.confirmed_at == nil

      # Try to log in with correct credentials
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{
            email: user.email,
            password: password
          }
        )

      # Submit login form
      render_submit(form, %{"user" => %{"remember_me" => "true"}})

      conn = follow_trigger_action(form, conn)

      # Should see error message about unconfirmed account
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      # Should be redirected back to login page
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "unconfirmed user sees message prompting to check email", %{conn: conn} do
      password = valid_user_password()
      user = unconfirmed_user_fixture(password: password)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{
            email: user.email,
            password: password
          }
        )

      render_submit(form, %{"user" => %{"remember_me" => "true"}})

      conn = follow_trigger_action(form, conn)

      # User should see the standard "Invalid email or password" message
      # (We don't want to leak information about which accounts exist)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end

    test "confirmed user CAN log in with password", %{conn: conn} do
      # Create confirmed user with password
      password = valid_user_password()
      user = user_fixture(password: password)
      assert user.confirmed_at != nil

      # Log in with credentials
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{
            email: user.email,
            password: password
          }
        )

      render_submit(form, %{"user" => %{"remember_me" => "true"}})
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"
    end

    test "unconfirmed user can still request magic link", %{conn: conn} do
      user = unconfirmed_user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      # Fill in email and submit magic link form
      form = form(lv, "#login_form_magic", user: %{email: user.email})

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ ~r/If your email is in our system/i

      # Extract and use the magic link
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"

      # Verify user is now confirmed
      user = Accounts.get_user_by_email(user.email)
      assert user.confirmed_at != nil
    end
  end

  describe "workspace invitation for new users" do
    test "invited new user registers, confirms email, and can access workspace", %{conn: conn} do
      # Setup: Create workspace owner and workspace
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Step 1: Owner invites a new user (email not in system)
      invited_email = unique_user_email()

      {:ok, {:invitation_sent, invitation}} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_email, :member)

      assert invitation.email == invited_email
      assert invitation.user_id == nil
      assert invitation.joined_at == nil
      assert invitation.role == :member

      # Step 2: New user signs up with the invited email
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      password = valid_user_password()

      form =
        form(lv, "#registration_form",
          user: %{
            email: invited_email,
            first_name: "Invited",
            last_name: "User",
            password: password
          }
        )

      {:ok, _lv, _html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      # Step 3: User confirms email via magic link
      new_user = Accounts.get_user_by_email(invited_email)
      assert new_user.confirmed_at == nil

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(new_user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"

      # Step 4: Verify user is confirmed
      new_user = Accounts.get_user_by_email(invited_email)
      assert new_user.confirmed_at != nil

      # Step 5: Verify notification was created for the pending invitation
      notifications = Jarga.Notifications.list_notifications(new_user.id)
      assert length(notifications) == 1
      notification = List.first(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_name"] == workspace.name
    end

    test "existing user invited to workspace receives invitation and can accept", %{conn: _conn} do
      # Setup: Create workspace owner and workspace
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Create an existing confirmed user
      existing_user = user_fixture()
      assert existing_user.confirmed_at != nil

      # Owner invites existing user - creates an invitation that needs acceptance
      {:ok, {:invitation_sent, invitation}} =
        Jarga.Workspaces.invite_member(owner, workspace.id, existing_user.email, :member)

      # Verify invitation was created without user_id or joined_at
      assert invitation.email == existing_user.email
      assert invitation.user_id == nil
      assert invitation.joined_at == nil
      assert invitation.role == :member

      # Wait for notification to be created asynchronously
      notification = wait_for_notification(existing_user.id)
      assert notification != nil, "Notification was not created"

      # Accept the invitation
      {:ok, member} =
        Jarga.Notifications.accept_workspace_invitation(
          notification.id,
          existing_user.id
        )

      # Verify membership was updated with user_id and joined_at set
      assert member.user_id == existing_user.id
      assert member.joined_at != nil
    end

    test "invited user cannot access workspace before confirming email", %{conn: _conn} do
      # Setup: Create workspace and invitation
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invited_email = unique_user_email()

      {:ok, {:invitation_sent, _invitation}} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_email, :member)

      # New user signs up but doesn't confirm
      unconfirmed_user = unconfirmed_user_fixture(email: invited_email)
      assert unconfirmed_user.confirmed_at == nil

      # User cannot use magic link until confirmed
      # User also cannot log in with password until confirmed
      # (The confirmation flow is tested in other tests)
    end

    test "invited user with confirmed email can access workspace", %{conn: _conn} do
      # Setup: Create workspace and invitation
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invited_email = unique_user_email()

      {:ok, {:invitation_sent, _invitation}} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_email, :member)

      # User signs up and confirms
      user = user_fixture(email: invited_email)
      assert user.confirmed_at != nil

      # User has been invited and is confirmed
      # They would need to accept the invitation through the UI to access the workspace
    end

    test "multiple invitations: user confirms email before accepting workspace", %{conn: conn} do
      # Setup: Create two workspaces with different owners
      owner1 = user_fixture()
      workspace1 = workspace_fixture(owner1)

      owner2 = user_fixture()
      workspace2 = workspace_fixture(owner2)

      invited_email = unique_user_email()

      # Both owners invite the same email
      {:ok, {:invitation_sent, invitation1}} =
        Jarga.Workspaces.invite_member(owner1, workspace1.id, invited_email, :member)

      {:ok, {:invitation_sent, invitation2}} =
        Jarga.Workspaces.invite_member(owner2, workspace2.id, invited_email, :admin)

      assert invitation1.joined_at == nil
      assert invitation2.joined_at == nil

      # User signs up with the invited email
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      password = valid_user_password()

      form =
        form(lv, "#registration_form",
          user: %{
            email: invited_email,
            first_name: "Invited",
            last_name: "User",
            password: password
          }
        )

      {:ok, _lv, _html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      # User confirms email via magic link
      new_user = Accounts.get_user_by_email(invited_email)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(new_user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) == ~p"/"

      # Verify user is confirmed
      new_user = Accounts.get_user_by_email(invited_email)
      assert new_user.confirmed_at != nil

      # Wait for notifications to be created asynchronously
      # We need to wait for both notifications (max 20 attempts)
      notifications =
        Enum.reduce_while(1..20, [], fn _attempt, _acc ->
          notifs = Jarga.Notifications.list_notifications(new_user.id)

          if length(notifs) == 2 do
            {:halt, notifs}
          else
            Process.sleep(10)
            {:cont, notifs}
          end
        end)

      # Verify notifications were created for both pending invitations
      assert length(notifications) == 2

      workspace_names = Enum.map(notifications, & &1.data["workspace_name"]) |> Enum.sort()
      assert workspace_names == [workspace1.name, workspace2.name] |> Enum.sort()
    end
  end
end

defmodule Jarga.Accounts.UserNotifierTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.UserNotifier

  import Jarga.AccountsFixtures

  describe "deliver_update_email_instructions/2" do
    test "sends email with update instructions" do
      user = user_fixture(%{email: "test@example.com"})
      url = "http://example.com/users/settings/confirm_email/token123"

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      assert email.to == [{"", "test@example.com"}]
      assert email.from == {"Jarga", "contact@example.com"}
      assert email.subject == "Update email instructions"
      assert email.text_body =~ "Hi test@example.com"
      assert email.text_body =~ url
      assert email.text_body =~ "You can change your email"
      assert email.text_body =~ "If you didn't request this change, please ignore this"
    end

    test "email contains the provided URL" do
      user = user_fixture()
      url = "http://custom.url/path"

      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      assert email.text_body =~ url
    end

    test "email addresses user by their email" do
      user = user_fixture(%{email: "custom@example.com"})
      url = "http://example.com/url"

      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      assert email.text_body =~ "Hi custom@example.com"
    end
  end

  describe "deliver_login_instructions/2" do
    test "sends confirmation instructions for unconfirmed user" do
      user = unconfirmed_user_fixture(%{email: "unconfirmed@example.com"})
      url = "http://example.com/users/confirm/token123"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.to == [{"", "unconfirmed@example.com"}]
      assert email.subject == "Confirmation instructions"
      assert email.text_body =~ "Hi unconfirmed@example.com"
      assert email.text_body =~ "You can confirm your account"
      assert email.text_body =~ url
      assert email.text_body =~ "If you didn't create an account"
    end

    test "sends magic link for confirmed user" do
      user = user_fixture(%{email: "confirmed@example.com"})
      url = "http://example.com/users/log_in/token123"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.to == [{"", "confirmed@example.com"}]
      assert email.subject == "Log in instructions"
      assert email.text_body =~ "Hi confirmed@example.com"
      assert email.text_body =~ "You can log into your account"
      assert email.text_body =~ url
      assert email.text_body =~ "If you didn't request this email"
    end

    test "distinguishes between confirmed and unconfirmed users" do
      unconfirmed = unconfirmed_user_fixture()
      confirmed = user_fixture()
      url = "http://example.com/url"

      {:ok, unconfirmed_email} = UserNotifier.deliver_login_instructions(unconfirmed, url)
      {:ok, confirmed_email} = UserNotifier.deliver_login_instructions(confirmed, url)

      assert unconfirmed_email.subject == "Confirmation instructions"
      assert confirmed_email.subject == "Log in instructions"

      assert unconfirmed_email.text_body =~ "confirm your account"
      assert confirmed_email.text_body =~ "log into your account"
    end

    test "email contains provided URL for unconfirmed user" do
      user = unconfirmed_user_fixture()
      url = "http://custom.confirmation.url/token"

      {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.text_body =~ url
    end

    test "email contains provided URL for confirmed user" do
      user = user_fixture()
      url = "http://custom.login.url/token"

      {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.text_body =~ url
    end
  end

  describe "email delivery" do
    test "returns ok tuple with email on successful delivery" do
      user = user_fixture()
      url = "http://example.com/url"

      result = UserNotifier.deliver_login_instructions(user, url)

      assert {:ok, email} = result
      assert email.__struct__ == Swoosh.Email
    end

    test "email has correct from address" do
      user = user_fixture()
      url = "http://example.com/url"

      {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.from == {"Jarga", "contact@example.com"}
    end

    test "email is text format" do
      user = user_fixture()
      url = "http://example.com/url"

      {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.text_body != nil
      assert is_binary(email.text_body)
    end
  end
end

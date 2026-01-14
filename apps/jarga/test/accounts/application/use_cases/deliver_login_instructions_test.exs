defmodule Jarga.Accounts.Application.UseCases.DeliverLoginInstructionsTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Swoosh.TestAssertions

  alias Jarga.Accounts.Application.UseCases.DeliverLoginInstructions
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema

  describe "execute/2" do
    setup do
      user = user_fixture()
      url_fun = fn token -> "http://example.com/login/#{token}" end
      %{user: user, url_fun: url_fun}
    end

    test "generates login token and sends email", %{user: user, url_fun: url_fun} do
      result =
        DeliverLoginInstructions.execute(%{
          user: user,
          url_fun: url_fun
        })

      # Should return the result from the notifier
      assert {:ok, _email} = result

      # Email should be sent
      assert_email_sent(to: user.email)
    end

    test "token context is login", %{user: user, url_fun: url_fun} do
      DeliverLoginInstructions.execute(%{
        user: user,
        url_fun: url_fun
      })

      # Token should exist in database with context "login"
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 1

      [user_token] = user_tokens
      assert user_token.context == "login"
      assert user_token.sent_to == user.email
    end

    test "email sent via UserNotifier", %{user: user, url_fun: url_fun} do
      DeliverLoginInstructions.execute(%{
        user: user,
        url_fun: url_fun
      })

      # Verify email was sent to the user
      assert_email_sent(to: user.email)
    end

    test "accepts injectable repo and notifier", %{user: user, url_fun: url_fun} do
      # Track insertions
      inserted_tokens = Agent.start_link(fn -> [] end)
      {:ok, agent} = inserted_tokens

      mock_repo = %{
        insert!: fn token ->
          Agent.update(agent, fn tokens -> [token | tokens] end)
          %{token | id: Ecto.UUID.generate()}
        end
      }

      # Track email deliveries
      mock_notifier = fn _user, _url ->
        {:ok, :email_sent}
      end

      result =
        DeliverLoginInstructions.execute(
          %{
            user: user,
            url_fun: url_fun
          },
          repo: mock_repo,
          notifier: mock_notifier
        )

      # Should return notifier result
      assert result == {:ok, :email_sent}

      # Verify token was inserted
      tokens = Agent.get(agent, & &1)
      assert length(tokens) == 1
      [inserted_token] = tokens
      assert inserted_token.context == "login"

      Agent.stop(agent)
    end

    test "multiple calls generate different tokens", %{user: user, url_fun: url_fun} do
      DeliverLoginInstructions.execute(%{user: user, url_fun: url_fun})
      DeliverLoginInstructions.execute(%{user: user, url_fun: url_fun})

      # Should have two tokens
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 2

      # Both should have context "login"
      Enum.each(user_tokens, fn token ->
        assert token.context == "login"
      end)
    end
  end
end

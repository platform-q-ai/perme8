defmodule Jarga.Accounts.Application.UseCases.DeliverUserUpdateEmailInstructionsTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Swoosh.TestAssertions

  alias Jarga.Accounts.Application.UseCases.DeliverUserUpdateEmailInstructions
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema

  describe "execute/2" do
    setup do
      user = user_fixture()
      current_email = user.email
      url_fun = fn token -> "http://example.com/confirm/#{token}" end
      %{user: user, current_email: current_email, url_fun: url_fun}
    end

    test "generates token and sends email", %{
      user: user,
      current_email: current_email,
      url_fun: url_fun
    } do
      result =
        DeliverUserUpdateEmailInstructions.execute(%{
          user: user,
          current_email: current_email,
          url_fun: url_fun
        })

      # Should return the result from the notifier
      assert {:ok, _email} = result

      # Email should be sent
      assert_email_sent(to: user.email)
    end

    test "token persisted in database with correct context", %{
      user: user,
      current_email: current_email,
      url_fun: url_fun
    } do
      DeliverUserUpdateEmailInstructions.execute(%{
        user: user,
        current_email: current_email,
        url_fun: url_fun
      })

      # Token should exist in database
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 1

      # Token context should include the current email
      [user_token] = user_tokens
      assert user_token.context == "change:#{current_email}"
      assert user_token.sent_to == user.email
    end

    test "email sent to user with URL", %{
      user: user,
      current_email: current_email,
      url_fun: url_fun
    } do
      DeliverUserUpdateEmailInstructions.execute(%{
        user: user,
        current_email: current_email,
        url_fun: url_fun
      })

      # Verify email was sent
      assert_email_sent(to: user.email)
    end

    test "accepts injectable repo and notifier", %{
      user: user,
      current_email: current_email,
      url_fun: url_fun
    } do
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
        DeliverUserUpdateEmailInstructions.execute(
          %{
            user: user,
            current_email: current_email,
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
      assert inserted_token.context == "change:#{current_email}"

      Agent.stop(agent)
    end

    test "context format includes current email", %{user: user, url_fun: url_fun} do
      current_email = "old@example.com"

      DeliverUserUpdateEmailInstructions.execute(%{
        user: user,
        current_email: current_email,
        url_fun: url_fun
      })

      # Token context should be "change:old@example.com"
      [user_token] = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert user_token.context == "change:old@example.com"
    end

    test "different current emails create different token contexts", %{
      user: user,
      url_fun: url_fun
    } do
      # First token with one email
      DeliverUserUpdateEmailInstructions.execute(%{
        user: user,
        current_email: "first@example.com",
        url_fun: url_fun
      })

      # Second token with different email
      DeliverUserUpdateEmailInstructions.execute(%{
        user: user,
        current_email: "second@example.com",
        url_fun: url_fun
      })

      # Should have two tokens with different contexts
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 2

      contexts = Enum.map(user_tokens, & &1.context) |> Enum.sort()
      assert contexts == ["change:first@example.com", "change:second@example.com"]
    end
  end
end

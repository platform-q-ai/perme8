defmodule Jarga.Accounts.Domain.Policies.TokenPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Policies.TokenPolicy

  describe "validity periods" do
    test "session_validity_days/0 returns 14" do
      assert TokenPolicy.session_validity_days() == 14
    end

    test "magic_link_validity_minutes/0 returns 15" do
      assert TokenPolicy.magic_link_validity_minutes() == 15
    end

    test "change_email_validity_days/0 returns 7" do
      assert TokenPolicy.change_email_validity_days() == 7
    end
  end

  describe "session_token_expired?/1" do
    test "returns true for token older than validity period" do
      old_timestamp = DateTime.utc_now() |> DateTime.add(-15, :day)

      assert TokenPolicy.session_token_expired?(old_timestamp)
    end

    test "returns false for token within validity period" do
      recent_timestamp = DateTime.utc_now() |> DateTime.add(-10, :day)

      refute TokenPolicy.session_token_expired?(recent_timestamp)
    end

    test "returns false for current timestamp" do
      now = DateTime.utc_now()

      refute TokenPolicy.session_token_expired?(now)
    end
  end

  describe "magic_link_token_expired?/1" do
    test "returns true for token older than validity period" do
      old_timestamp = DateTime.utc_now() |> DateTime.add(-20, :minute)

      assert TokenPolicy.magic_link_token_expired?(old_timestamp)
    end

    test "returns false for token within validity period" do
      recent_timestamp = DateTime.utc_now() |> DateTime.add(-10, :minute)

      refute TokenPolicy.magic_link_token_expired?(recent_timestamp)
    end

    test "returns false for current timestamp" do
      now = DateTime.utc_now()

      refute TokenPolicy.magic_link_token_expired?(now)
    end
  end

  describe "change_email_token_expired?/1" do
    test "returns true for token older than validity period" do
      old_timestamp = DateTime.utc_now() |> DateTime.add(-8, :day)

      assert TokenPolicy.change_email_token_expired?(old_timestamp)
    end

    test "returns false for token within validity period" do
      recent_timestamp = DateTime.utc_now() |> DateTime.add(-3, :day)

      refute TokenPolicy.change_email_token_expired?(recent_timestamp)
    end
  end
end

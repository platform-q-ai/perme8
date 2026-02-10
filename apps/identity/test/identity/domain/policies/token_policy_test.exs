defmodule Identity.Domain.Policies.TokenPolicyTest do
  @moduledoc """
  Unit tests for the TokenPolicy domain policy.

  These are pure tests with no database access, testing business rules
  for token expiration.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Policies.TokenPolicy

  describe "session_validity_days/0" do
    test "returns 14 days" do
      assert TokenPolicy.session_validity_days() == 14
    end
  end

  describe "magic_link_validity_minutes/0" do
    test "returns 15 minutes" do
      assert TokenPolicy.magic_link_validity_minutes() == 15
    end
  end

  describe "change_email_validity_days/0" do
    test "returns 7 days" do
      assert TokenPolicy.change_email_validity_days() == 7
    end
  end

  describe "session_token_expired?/2" do
    test "returns false for token created less than 14 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 10 days ago
      created_at = ~U[2024-01-05 12:00:00Z]

      assert TokenPolicy.session_token_expired?(created_at, now) == false
    end

    test "returns false for token created exactly 14 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created exactly 14 days ago
      created_at = ~U[2024-01-01 12:00:00Z]

      # Exactly at cutoff - not expired yet
      assert TokenPolicy.session_token_expired?(created_at, now) == false
    end

    test "returns true for token created more than 14 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 15 days ago
      created_at = ~U[2023-12-31 12:00:00Z]

      assert TokenPolicy.session_token_expired?(created_at, now) == true
    end

    test "returns false for token created just now" do
      now = ~U[2024-01-15 12:00:00Z]

      assert TokenPolicy.session_token_expired?(now, now) == false
    end

    test "uses DateTime.utc_now when current_time not provided" do
      # Token created just now should not be expired
      assert TokenPolicy.session_token_expired?(DateTime.utc_now()) == false
    end
  end

  describe "magic_link_token_expired?/2" do
    test "returns false for token created less than 15 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 10 minutes ago
      created_at = ~U[2024-01-15 11:50:00Z]

      assert TokenPolicy.magic_link_token_expired?(created_at, now) == false
    end

    test "returns false for token created exactly 15 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created exactly 15 minutes ago
      created_at = ~U[2024-01-15 11:45:00Z]

      # Exactly at cutoff - not expired yet
      assert TokenPolicy.magic_link_token_expired?(created_at, now) == false
    end

    test "returns true for token created more than 15 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 20 minutes ago
      created_at = ~U[2024-01-15 11:40:00Z]

      assert TokenPolicy.magic_link_token_expired?(created_at, now) == true
    end

    test "returns true for token created 30 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 30 minutes ago
      created_at = ~U[2024-01-15 11:30:00Z]

      assert TokenPolicy.magic_link_token_expired?(created_at, now) == true
    end

    test "returns false for token created just now" do
      now = ~U[2024-01-15 12:00:00Z]

      assert TokenPolicy.magic_link_token_expired?(now, now) == false
    end
  end

  describe "change_email_token_expired?/2" do
    test "returns false for token created less than 7 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 5 days ago
      created_at = ~U[2024-01-10 12:00:00Z]

      assert TokenPolicy.change_email_token_expired?(created_at, now) == false
    end

    test "returns false for token created exactly 7 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created exactly 7 days ago
      created_at = ~U[2024-01-08 12:00:00Z]

      # Exactly at cutoff - not expired yet
      assert TokenPolicy.change_email_token_expired?(created_at, now) == false
    end

    test "returns true for token created more than 7 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 8 days ago
      created_at = ~U[2024-01-07 11:00:00Z]

      assert TokenPolicy.change_email_token_expired?(created_at, now) == true
    end

    test "returns true for token created 10 days ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Created 10 days ago
      created_at = ~U[2024-01-05 12:00:00Z]

      assert TokenPolicy.change_email_token_expired?(created_at, now) == true
    end

    test "returns false for token created just now" do
      now = ~U[2024-01-15 12:00:00Z]

      assert TokenPolicy.change_email_token_expired?(now, now) == false
    end
  end
end

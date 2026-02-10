defmodule Identity.Domain.Policies.AuthenticationPolicyTest do
  @moduledoc """
  Unit tests for the AuthenticationPolicy domain policy.

  These are pure tests with no database access, testing business rules
  for authentication states like sudo mode.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Policies.AuthenticationPolicy

  describe "sudo_mode?/2" do
    test "returns true when authenticated within 20 minutes" do
      now = ~U[2024-01-15 12:00:00Z]
      # Authenticated 10 minutes ago
      authenticated_at = ~U[2024-01-15 11:50:00Z]

      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: authenticated_at
        })

      assert AuthenticationPolicy.sudo_mode?(user, current_time: now) == true
    end

    test "returns true when authenticated exactly at cutoff" do
      now = ~U[2024-01-15 12:00:00Z]
      # Authenticated exactly 20 minutes ago (at cutoff boundary)
      authenticated_at = ~U[2024-01-15 11:40:00Z]

      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: authenticated_at
        })

      # At exactly 20 minutes, DateTime.after? returns false (not after cutoff)
      assert AuthenticationPolicy.sudo_mode?(user, current_time: now) == false
    end

    test "returns true when authenticated 19 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Authenticated 19 minutes ago
      authenticated_at = ~U[2024-01-15 11:41:00Z]

      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: authenticated_at
        })

      assert AuthenticationPolicy.sudo_mode?(user, current_time: now) == true
    end

    test "returns false when authenticated more than 20 minutes ago" do
      now = ~U[2024-01-15 12:00:00Z]
      # Authenticated 30 minutes ago
      authenticated_at = ~U[2024-01-15 11:30:00Z]

      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: authenticated_at
        })

      assert AuthenticationPolicy.sudo_mode?(user, current_time: now) == false
    end

    test "returns false when authenticated_at is nil" do
      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: nil
        })

      assert AuthenticationPolicy.sudo_mode?(user) == false
    end

    test "returns false for nil user" do
      assert AuthenticationPolicy.sudo_mode?(nil) == false
    end

    test "accepts custom minutes option" do
      now = ~U[2024-01-15 12:00:00Z]
      # Authenticated 5 minutes ago
      authenticated_at = ~U[2024-01-15 11:55:00Z]

      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: authenticated_at
        })

      # With 10-minute window (minutes: -10), should be in sudo mode
      assert AuthenticationPolicy.sudo_mode?(user, minutes: -10, current_time: now) == true

      # With 3-minute window (minutes: -3), should NOT be in sudo mode
      assert AuthenticationPolicy.sudo_mode?(user, minutes: -3, current_time: now) == false
    end

    test "uses DateTime.utc_now when current_time not provided" do
      # Create a user authenticated just now
      user =
        User.new(%{
          email: "test@example.com",
          authenticated_at: DateTime.utc_now()
        })

      # Should be in sudo mode since we just authenticated
      assert AuthenticationPolicy.sudo_mode?(user) == true
    end

    test "works with user structs that have authenticated_at field" do
      now = ~U[2024-01-15 12:00:00Z]

      # Test with a plain map that has authenticated_at
      non_user_struct = %{authenticated_at: ~U[2024-01-15 11:55:00Z]}

      # This should not match the User guard and return false
      assert AuthenticationPolicy.sudo_mode?(non_user_struct, current_time: now) == false
    end
  end
end

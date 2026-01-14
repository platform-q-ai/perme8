defmodule Jarga.Accounts.Domain.Policies.AuthenticationPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Policies.AuthenticationPolicy
  alias Jarga.Accounts.Domain.Entities.User

  describe "sudo_mode?/2" do
    test "returns true when authenticated within time limit" do
      authenticated_at = DateTime.utc_now() |> DateTime.add(-10, :minute)
      user = %User{authenticated_at: authenticated_at}

      assert AuthenticationPolicy.sudo_mode?(user, -20)
    end

    test "returns false when authenticated beyond time limit" do
      authenticated_at = DateTime.utc_now() |> DateTime.add(-30, :minute)
      user = %User{authenticated_at: authenticated_at}

      refute AuthenticationPolicy.sudo_mode?(user, -20)
    end

    test "returns false when user has no authenticated_at" do
      user = %User{authenticated_at: nil}

      refute AuthenticationPolicy.sudo_mode?(user)
    end

    test "returns false for nil user" do
      refute AuthenticationPolicy.sudo_mode?(nil)
    end

    test "uses default minutes of -20" do
      authenticated_at = DateTime.utc_now() |> DateTime.add(-15, :minute)
      user = %User{authenticated_at: authenticated_at}

      assert AuthenticationPolicy.sudo_mode?(user)
    end

    test "allows custom time limit" do
      authenticated_at = DateTime.utc_now() |> DateTime.add(-5, :minute)
      user = %User{authenticated_at: authenticated_at}

      assert AuthenticationPolicy.sudo_mode?(user, -10)
      refute AuthenticationPolicy.sudo_mode?(user, -3)
    end
  end
end

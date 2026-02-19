defmodule Identity.ApplicationLayerTest do
  use ExUnit.Case, async: true

  describe "use_cases/0" do
    test "includes workspace use cases" do
      use_cases = Identity.ApplicationLayer.use_cases()

      assert Identity.Application.UseCases.InviteMember in use_cases
      assert Identity.Application.UseCases.ChangeMemberRole in use_cases
      assert Identity.Application.UseCases.RemoveMember in use_cases
      assert Identity.Application.UseCases.CreateNotificationsForPendingInvitations in use_cases
    end

    test "includes all original use cases" do
      use_cases = Identity.ApplicationLayer.use_cases()

      assert Identity.Application.UseCases.RegisterUser in use_cases
      assert Identity.Application.UseCases.LoginByMagicLink in use_cases
    end
  end

  describe "services/0" do
    test "includes all services" do
      services = Identity.ApplicationLayer.services()

      assert Identity.Application.Services.PasswordService in services
      assert Identity.Application.Services.ApiKeyTokenService in services
    end
  end

  describe "behaviours/0" do
    test "includes workspace behaviours" do
      behaviours = Identity.ApplicationLayer.behaviours()

      assert Identity.Application.Behaviours.MembershipRepositoryBehaviour in behaviours
      assert Identity.Application.Behaviours.WorkspaceNotifierBehaviour in behaviours
      assert Identity.Application.Behaviours.WorkspaceQueriesBehaviour in behaviours
    end

    test "includes all original behaviours" do
      behaviours = Identity.ApplicationLayer.behaviours()

      assert Identity.Application.Behaviours.UserRepositoryBehaviour in behaviours
    end
  end

  describe "summary/0" do
    test "returns correct counts including workspace modules" do
      summary = Identity.ApplicationLayer.summary()

      # 12 original + 4 workspace = 16
      assert summary.use_cases == 16
      # 2 original services
      assert summary.services == 2
      # 7 original + 3 workspace = 10
      assert summary.behaviours == 10
      # Total = 16 + 2 + 10 = 28
      assert summary.total == 28
    end
  end
end

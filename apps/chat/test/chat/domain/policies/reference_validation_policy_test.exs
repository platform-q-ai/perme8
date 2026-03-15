defmodule Chat.Domain.Policies.ReferenceValidationPolicyTest do
  use ExUnit.Case, async: true

  alias Chat.Domain.Policies.ReferenceValidationPolicy

  describe "validate_user_reference/1" do
    test "returns :ok when user exists" do
      assert :ok = ReferenceValidationPolicy.validate_user_reference(true)
    end

    test "returns {:error, :user_not_found} when user does not exist" do
      assert {:error, :user_not_found} = ReferenceValidationPolicy.validate_user_reference(false)
    end

    test "returns {:error, :identity_unavailable} when Identity is unreachable" do
      assert {:error, :identity_unavailable} =
               ReferenceValidationPolicy.validate_user_reference({:error, :timeout})
    end

    test "returns {:error, :identity_unavailable} for any error tuple" do
      assert {:error, :identity_unavailable} =
               ReferenceValidationPolicy.validate_user_reference({:error, :nxdomain})
    end
  end

  describe "validate_workspace_reference/1" do
    test "returns :ok when workspace_id is nil (optional)" do
      assert :ok = ReferenceValidationPolicy.validate_workspace_reference(nil)
    end

    test "returns :ok when workspace validation passes" do
      assert :ok = ReferenceValidationPolicy.validate_workspace_reference(:ok)
    end

    test "returns {:error, :workspace_not_found} for workspace not found" do
      assert {:error, :workspace_not_found} =
               ReferenceValidationPolicy.validate_workspace_reference(
                 {:error, :workspace_not_found}
               )
    end

    test "returns {:error, :not_a_member} when user is not a member" do
      assert {:error, :not_a_member} =
               ReferenceValidationPolicy.validate_workspace_reference({:error, :not_a_member})
    end
  end

  describe "validate_references/2" do
    test "returns :ok when both user and workspace are valid" do
      assert :ok = ReferenceValidationPolicy.validate_references(true, :ok)
    end

    test "returns :ok when user exists and no workspace provided" do
      assert :ok = ReferenceValidationPolicy.validate_references(true, nil)
    end

    test "returns user error when user validation fails" do
      assert {:error, :user_not_found} =
               ReferenceValidationPolicy.validate_references(false, :ok)
    end

    test "returns workspace error when user valid but workspace fails" do
      assert {:error, :not_a_member} =
               ReferenceValidationPolicy.validate_references(true, {:error, :not_a_member})
    end

    test "returns user error first when both fail" do
      assert {:error, :user_not_found} =
               ReferenceValidationPolicy.validate_references(
                 false,
                 {:error, :workspace_not_found}
               )
    end

    test "returns identity_unavailable when Identity is unreachable" do
      assert {:error, :identity_unavailable} =
               ReferenceValidationPolicy.validate_references({:error, :timeout}, nil)
    end
  end
end

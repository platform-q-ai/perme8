defmodule Webhooks.Domain.Policies.WebhookAuthorizationPolicyTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  describe "can_manage_webhooks?/1" do
    test "returns true for :owner role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(:owner) == true
    end

    test "returns true for :admin role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(:admin) == true
    end

    test "returns false for :member role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(:member) == false
    end

    test "returns false for :guest role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(:guest) == false
    end

    test "returns false for nil role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(nil) == false
    end

    test "returns false for unknown role" do
      assert WebhookAuthorizationPolicy.can_manage_webhooks?(:viewer) == false
    end
  end
end

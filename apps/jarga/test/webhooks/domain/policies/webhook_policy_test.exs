defmodule Jarga.Webhooks.Domain.Policies.WebhookPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  describe "can_manage_webhooks?/1" do
    test "returns true for :admin role" do
      assert WebhookPolicy.can_manage_webhooks?(:admin) == true
    end

    test "returns true for :owner role" do
      assert WebhookPolicy.can_manage_webhooks?(:owner) == true
    end

    test "returns false for :member role" do
      assert WebhookPolicy.can_manage_webhooks?(:member) == false
    end

    test "returns false for :guest role" do
      assert WebhookPolicy.can_manage_webhooks?(:guest) == false
    end
  end
end

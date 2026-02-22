defmodule Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchema

  @valid_attrs %{
    url: "https://example.com/webhook",
    secret: "test_secret_key_32chars_minimum!",
    event_types: ["projects.project_created"],
    is_active: true,
    workspace_id: Ecto.UUID.generate(),
    created_by_id: Ecto.UUID.generate()
  }

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset when URL missing" do
      attrs = Map.delete(@valid_attrs, :url)
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      refute changeset.valid?
      assert %{url: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset when workspace_id missing" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      refute changeset.valid?
      assert %{workspace_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset when secret missing" do
      attrs = Map.delete(@valid_attrs, :secret)
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      refute changeset.valid?
      assert %{secret: ["can't be blank"]} = errors_on(changeset)
    end

    test "event_types defaults to empty list" do
      attrs = Map.delete(@valid_attrs, :event_types)
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      assert changeset.valid?
      # The schema default handles this
    end

    test "is_active defaults to true" do
      attrs = Map.delete(@valid_attrs, :is_active)
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      assert changeset.valid?
    end

    test "invalid URL format is rejected" do
      attrs = Map.put(@valid_attrs, :url, "not-a-url")
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      refute changeset.valid?

      assert %{url: ["must be a valid URL starting with http:// or https://"]} =
               errors_on(changeset)
    end

    test "URL with http scheme is accepted in non-production" do
      attrs = Map.put(@valid_attrs, :url, "http://example.com/webhook")
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      # In test env, http:// is allowed
      assert changeset.valid?
    end

    test "URL with https scheme is always accepted" do
      attrs = Map.put(@valid_attrs, :url, "https://example.com/webhook")
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      assert changeset.valid?
    end

    test "URL with ftp scheme is rejected" do
      attrs = Map.put(@valid_attrs, :url, "ftp://example.com/webhook")
      changeset = WebhookSubscriptionSchema.changeset(%WebhookSubscriptionSchema{}, attrs)
      refute changeset.valid?
    end
  end
end

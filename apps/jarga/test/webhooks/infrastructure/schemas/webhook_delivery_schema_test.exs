defmodule Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema

  @valid_attrs %{
    webhook_subscription_id: Ecto.UUID.generate(),
    event_type: "projects.project_created",
    payload: %{"project_id" => "abc123"},
    status: "pending",
    attempts: 0,
    max_attempts: 5
  }

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires webhook_subscription_id" do
      attrs = Map.delete(@valid_attrs, :webhook_subscription_id)
      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
      refute changeset.valid?
      assert %{webhook_subscription_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires event_type" do
      attrs = Map.delete(@valid_attrs, :event_type)
      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
      refute changeset.valid?
      assert %{event_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires payload" do
      attrs = Map.delete(@valid_attrs, :payload)
      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
      refute changeset.valid?
      assert %{payload: ["can't be blank"]} = errors_on(changeset)
    end

    test "status defaults to pending" do
      changeset =
        WebhookDeliverySchema.changeset(
          %WebhookDeliverySchema{},
          Map.delete(@valid_attrs, :status)
        )

      assert changeset.valid?
    end

    test "status must be one of pending, success, failed" do
      attrs = Map.put(@valid_attrs, :status, "invalid_status")
      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid status values" do
      for status <- ["pending", "success", "failed"] do
        attrs = Map.put(@valid_attrs, :status, status)
        changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
        assert changeset.valid?, "Expected status '#{status}' to be valid"
      end
    end

    test "accepts optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          response_code: 200,
          response_body: "OK",
          next_retry_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      changeset = WebhookDeliverySchema.changeset(%WebhookDeliverySchema{}, attrs)
      assert changeset.valid?
    end
  end
end

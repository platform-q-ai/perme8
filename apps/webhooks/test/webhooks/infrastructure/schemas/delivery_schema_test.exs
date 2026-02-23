defmodule Webhooks.Infrastructure.Schemas.DeliverySchemaTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Schemas.{DeliverySchema, SubscriptionSchema}

  setup do
    # Create a subscription first (required FK)
    {:ok, subscription} =
      %SubscriptionSchema{}
      |> SubscriptionSchema.changeset(%{
        url: "https://example.com/webhook",
        secret: "whsec_test_secret_long_enough",
        event_types: ["projects.project_created"],
        workspace_id: Ecto.UUID.generate()
      })
      |> Repo.insert()

    %{subscription: subscription}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{subscription: subscription} do
      attrs = %{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{"project_id" => "123"},
        status: "pending"
      }

      changeset = DeliverySchema.changeset(%DeliverySchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :subscription_id) == subscription.id
      assert get_change(changeset, :event_type) == "projects.project_created"
    end

    test "requires subscription_id" do
      attrs = %{event_type: "projects.project_created", payload: %{}}
      changeset = DeliverySchema.changeset(%DeliverySchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subscription_id
    end

    test "requires event_type", %{subscription: subscription} do
      attrs = %{subscription_id: subscription.id, payload: %{}}
      changeset = DeliverySchema.changeset(%DeliverySchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).event_type
    end

    test "defaults status to pending" do
      schema = %DeliverySchema{}
      assert schema.status == "pending"
    end

    test "defaults attempts to 0" do
      schema = %DeliverySchema{}
      assert schema.attempts == 0
    end

    test "defaults max_attempts to 5" do
      schema = %DeliverySchema{}
      assert schema.max_attempts == 5
    end

    test "validates status is one of pending, success, failed", %{subscription: subscription} do
      attrs = %{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{},
        status: "invalid_status"
      }

      changeset = DeliverySchema.changeset(%DeliverySchema{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "casts payload as map", %{subscription: subscription} do
      attrs = %{
        subscription_id: subscription.id,
        event_type: "projects.project_created",
        payload: %{"key" => "value"}
      }

      changeset = DeliverySchema.changeset(%DeliverySchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :payload) == %{"key" => "value"}
    end
  end

  describe "to_entity/1" do
    test "converts schema to domain entity" do
      now = DateTime.utc_now()
      sub_id = Ecto.UUID.generate()

      schema = %DeliverySchema{
        id: Ecto.UUID.generate(),
        subscription_id: sub_id,
        event_type: "projects.project_created",
        payload: %{"project_id" => "123"},
        status: "success",
        response_code: 200,
        response_body: "OK",
        attempts: 1,
        max_attempts: 5,
        next_retry_at: nil,
        inserted_at: now,
        updated_at: now
      }

      entity = DeliverySchema.to_entity(schema)

      assert entity.__struct__ == Webhooks.Domain.Entities.Delivery
      assert entity.id == schema.id
      assert entity.subscription_id == sub_id
      assert entity.event_type == "projects.project_created"
      assert entity.payload == %{"project_id" => "123"}
      assert entity.status == "success"
      assert entity.response_code == 200
      assert entity.attempts == 1
    end
  end

  describe "database integration" do
    test "inserts and retrieves delivery", %{subscription: subscription} do
      {:ok, delivery} =
        %DeliverySchema{}
        |> DeliverySchema.changeset(%{
          subscription_id: subscription.id,
          event_type: "projects.project_created",
          payload: %{"project_id" => "123"}
        })
        |> Repo.insert()

      assert delivery.id != nil
      assert delivery.status == "pending"
      assert delivery.attempts == 0
    end
  end
end

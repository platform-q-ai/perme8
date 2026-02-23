defmodule Webhooks.Infrastructure.Schemas.SubscriptionSchemaTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Schemas.SubscriptionSchema

  @valid_attrs %{
    url: "https://example.com/webhook",
    secret: "whsec_test_secret_that_is_long_enough_for_validation",
    event_types: ["projects.project_created", "documents.document_created"],
    workspace_id: Ecto.UUID.generate(),
    created_by_id: Ecto.UUID.generate()
  }

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :url) == @valid_attrs.url
      assert get_change(changeset, :secret) == @valid_attrs.secret
      assert get_change(changeset, :event_types) == @valid_attrs.event_types
      assert get_change(changeset, :workspace_id) == @valid_attrs.workspace_id
    end

    test "requires url" do
      attrs = Map.delete(@valid_attrs, :url)
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).url
    end

    test "requires secret" do
      attrs = Map.delete(@valid_attrs, :secret)
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).secret
    end

    test "requires workspace_id" do
      attrs = Map.delete(@valid_attrs, :workspace_id)
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "validates url format must start with http(s)://" do
      attrs = Map.put(@valid_attrs, :url, "not-a-url")
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, attrs)

      refute changeset.valid?
      assert "must be a valid URL starting with http:// or https://" in errors_on(changeset).url
    end

    test "accepts http:// urls (for test environments)" do
      attrs = Map.put(@valid_attrs, :url, "http://localhost:4000/webhook")
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, attrs)

      assert changeset.valid?
    end

    test "casts event_types as array of strings" do
      changeset = SubscriptionSchema.changeset(%SubscriptionSchema{}, @valid_attrs)

      assert get_change(changeset, :event_types) == [
               "projects.project_created",
               "documents.document_created"
             ]
    end

    test "defaults is_active to true" do
      # is_active defaults to true via the schema definition
      schema = %SubscriptionSchema{}
      assert schema.is_active == true
    end
  end

  describe "to_entity/1" do
    test "converts schema struct to domain entity" do
      workspace_id = Ecto.UUID.generate()
      created_by_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      schema = %SubscriptionSchema{
        id: Ecto.UUID.generate(),
        url: "https://example.com/webhook",
        secret: "whsec_test_secret",
        event_types: ["projects.project_created"],
        is_active: true,
        workspace_id: workspace_id,
        created_by_id: created_by_id,
        inserted_at: now,
        updated_at: now
      }

      entity = SubscriptionSchema.to_entity(schema)

      assert entity.__struct__ == Webhooks.Domain.Entities.Subscription
      assert entity.id == schema.id
      assert entity.url == schema.url
      assert entity.secret == schema.secret
      assert entity.event_types == schema.event_types
      assert entity.is_active == true
      assert entity.workspace_id == workspace_id
      assert entity.created_by_id == created_by_id
      assert entity.inserted_at == now
      assert entity.updated_at == now
    end
  end

  describe "database integration" do
    test "inserts and retrieves subscription" do
      {:ok, subscription} =
        %SubscriptionSchema{}
        |> SubscriptionSchema.changeset(@valid_attrs)
        |> Repo.insert()

      assert subscription.id != nil
      assert subscription.url == @valid_attrs.url
      assert subscription.is_active == true
    end
  end
end

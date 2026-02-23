defmodule Webhooks.Infrastructure.Repositories.InboundWebhookConfigRepositoryTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Repositories.InboundWebhookConfigRepository
  alias Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema
  alias Webhooks.Domain.Entities.InboundWebhookConfig

  @workspace_id Ecto.UUID.generate()

  describe "get_by_workspace_id/2" do
    test "returns config as domain entity when it exists" do
      {:ok, _config} =
        %InboundWebhookConfigSchema{}
        |> InboundWebhookConfigSchema.changeset(%{
          workspace_id: @workspace_id,
          secret: "whsec_inbound_secret_long_enough"
        })
        |> Repo.insert()

      assert {:ok, %InboundWebhookConfig{} = entity} =
               InboundWebhookConfigRepository.get_by_workspace_id(@workspace_id, Repo)

      assert entity.workspace_id == @workspace_id
      assert entity.secret == "whsec_inbound_secret_long_enough"
      assert entity.is_active == true
    end

    test "returns :not_found when no config exists" do
      assert {:error, :not_found} =
               InboundWebhookConfigRepository.get_by_workspace_id(Ecto.UUID.generate(), Repo)
    end
  end
end

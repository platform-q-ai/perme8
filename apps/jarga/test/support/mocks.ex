Mox.defmock(Jarga.Webhooks.Mocks.MockWebhookRepository,
  for: Jarga.Webhooks.Application.Behaviours.WebhookRepositoryBehaviour
)

Mox.defmock(Jarga.Webhooks.Mocks.MockDeliveryRepository,
  for: Jarga.Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour
)

Mox.defmock(Jarga.Webhooks.Mocks.MockInboundWebhookRepository,
  for: Jarga.Webhooks.Application.Behaviours.InboundWebhookRepositoryBehaviour
)

Mox.defmock(Jarga.Webhooks.Mocks.MockHttpClient,
  for: Jarga.Webhooks.Application.Behaviours.HttpClientBehaviour
)

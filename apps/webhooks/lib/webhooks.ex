defmodule Webhooks do
  @moduledoc """
  The Webhooks context facade.

  Provides the public API for outbound webhook subscriptions
  (event-driven HTTP POST dispatches with HMAC-SHA256 signing)
  and inbound webhook reception (signature verification and audit logging).
  """

  use Boundary,
    top_level?: true,
    deps: [
      Webhooks.Domain
    ],
    exports: []
end

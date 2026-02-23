defmodule WebhooksApi.Router do
  use WebhooksApi, :router

  pipeline :api_base do
    plug(:accepts, ["json"])
  end

  # Routes will be added in later phases
end

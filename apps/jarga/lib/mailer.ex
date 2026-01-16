defmodule Jarga.Mailer do
  # Shared infrastructure - can be used by all contexts
  # Cannot depend on contexts or web layer
  use Boundary, top_level?: true, deps: []

  use Swoosh.Mailer, otp_app: :jarga
end

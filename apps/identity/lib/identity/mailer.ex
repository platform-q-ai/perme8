defmodule Identity.Mailer do
  @moduledoc """
  Email delivery for the Identity app.
  """

  # Shared infrastructure - can be used by all Identity modules
  use Boundary, top_level?: true, deps: []

  use Swoosh.Mailer, otp_app: :identity
end

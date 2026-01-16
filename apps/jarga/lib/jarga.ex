defmodule Jarga do
  @moduledoc """
  Jarga keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # Root namespace module - documentation only
  # Contexts are top-level boundaries (siblings, not children)
  use Boundary, top_level?: true, deps: [], exports: []
end

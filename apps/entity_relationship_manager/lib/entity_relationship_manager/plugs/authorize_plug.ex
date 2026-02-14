defmodule EntityRelationshipManager.Plugs.AuthorizePlug do
  @moduledoc """
  Plug for role-based authorization on API actions.

  Checks whether the current member's role is authorized to perform the
  requested action using `AuthorizationPolicy.can?/2`.

  ## Usage

      plug EntityRelationshipManager.Plugs.AuthorizePlug, action: :create_entity
  """

  import Plug.Conn

  @behaviour Plug

  alias EntityRelationshipManager.Domain.Policies.AuthorizationPolicy

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    action = Keyword.fetch!(opts, :action)
    member = conn.assigns[:member]

    if member && AuthorizationPolicy.can?(member.role, action) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        403,
        Jason.encode!(%{
          error: "forbidden",
          message: "You do not have permission to perform this action"
        })
      )
      |> halt()
    end
  end
end

defmodule EntityRelationshipManager.Plugs.WorkspaceAuthPlug do
  @moduledoc """
  Plug for authenticating API requests and verifying workspace membership.

  Extracts a Bearer token from the Authorization header, verifies the API key,
  fetches the user, and checks workspace membership. On success, assigns
  `:current_user`, `:api_key`, `:workspace_id`, and `:member` to the conn.

  ## Dependency Injection

  Dependencies are injected via the opts (second arg to `call/2`) for testability:

  - `verify_api_key` - `fn token -> {:ok, api_key} | {:error, reason} end`
  - `get_user` - `fn user_id -> user | nil end`
  - `get_member` - `fn user, workspace_id -> {:ok, member} | {:error, reason} end`

  In production, `init/1` returns `[]` and `call/2` uses the real modules.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{assigns: %{member: %{}, current_user: %{}}} = conn, _opts) do
    # Already authenticated (e.g. in tests) — pass through
    conn
  end

  def call(conn, opts) do
    workspace_id = conn.params["workspace_id"]

    verify_api_key_fn = Keyword.get(opts, :verify_api_key, &Identity.verify_api_key/1)
    get_user_fn = Keyword.get(opts, :get_user, &Identity.get_user/1)
    get_member_fn = Keyword.get(opts, :get_member, &Jarga.Workspaces.get_member/2)

    with {:ok, workspace_id} <- validate_workspace_id(workspace_id),
         {:ok, token} <- extract_bearer_token(conn),
         {:ok, api_key} <- verify_api_key_fn.(token),
         {:ok, user} <- fetch_user(get_user_fn, api_key.user_id),
         {:ok, member} <- get_member_fn.(user, workspace_id) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_key, api_key)
      |> assign(:workspace_id, workspace_id)
      |> assign(:member, member)
    else
      {:error, :invalid_uuid} ->
        bad_request(conn, "Invalid workspace ID format")

      {:error, :missing_token} ->
        unauthorized(conn)

      {:error, :invalid_api_key} ->
        unauthorized(conn)

      {:error, :invalid} ->
        unauthorized(conn)

      {:error, :inactive} ->
        unauthorized(conn)

      {:error, :revoked} ->
        unauthorized(conn)

      {:error, :user_not_found} ->
        unauthorized(conn)

      {:error, :unauthorized} ->
        not_found(conn)

      {:error, :workspace_not_found} ->
        not_found(conn)

      {:error, _} ->
        unauthorized(conn)
    end
  end

  defp validate_workspace_id(nil), do: {:error, :invalid_uuid}

  defp validate_workspace_id(workspace_id) do
    case Ecto.UUID.cast(workspace_id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        {:ok, String.trim(token)}

      _ ->
        {:error, :missing_token}
    end
  end

  defp fetch_user(get_user_fn, user_id) do
    case get_user_fn.(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized", message: "Authentication required"}))
    |> halt()
  end

  defp not_found(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found", message: "Resource not found"}))
    |> halt()
  end

  defp bad_request(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: "bad_request", message: message}))
    |> halt()
  end
end

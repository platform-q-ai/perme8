defmodule JargaApi.Plugs.ApiAuthPlug do
  @moduledoc """
  Plug for authenticating API requests using Bearer token.

  Extracts the API key token from the Authorization header,
  verifies it using `Identity.verify_api_key/1`,
  and assigns the verified API key and its owner (user) to the connection.

  ## Usage

  Add to your router pipeline:

      pipeline :api_authenticated do
        plug :accepts, ["json"]
        plug JargaApi.Plugs.ApiAuthPlug
      end

  ## Authorization Header Format

  The plug expects the Authorization header in Bearer token format:

      Authorization: Bearer <api_key_token>

  ## Success Response

  On successful authentication, the plug assigns:
  - `:api_key` - The verified API key entity
  - `:current_user` - The user who owns the API key

  This allows the API to act as the user, respecting existing authorization policies.

  ## Error Response

  On authentication failure, the plug returns a 401 Unauthorized response
  with a JSON error body:

      {"error": "Invalid or revoked API key"}

  """

  import Plug.Conn

  @behaviour Plug

  @error_message "Invalid or revoked API key"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, api_key} <- Identity.verify_api_key(token),
         {:ok, user} <- fetch_user(api_key.user_id) do
      conn
      |> assign(:api_key, api_key)
      |> assign(:current_user, user)
    else
      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp fetch_user(user_id) do
    case Identity.get_user(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
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

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: @error_message}))
    |> halt()
  end
end

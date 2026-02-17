defmodule KnowledgeMcp.Infrastructure.Mcp.AuthPlug do
  @moduledoc """
  Plug that extracts an API key from the Authorization header and authenticates.

  On success, assigns `workspace_id` and `user_id` to the connection.
  On failure, returns a 401 JSON response and halts the pipeline.

  ## Options

    * `:identity_module` - Module implementing IdentityBehaviour (passed to AuthenticateRequest)
  """

  @behaviour Plug

  import Plug.Conn

  alias KnowledgeMcp.Application.UseCases.AuthenticateRequest

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    case extract_bearer_token(conn) do
      {:ok, token} ->
        authenticate(conn, token, opts)

      :error ->
        unauthorized(conn, "Missing or invalid Authorization header")
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [header | _] -> parse_bearer(header)
      [] -> :error
    end
  end

  defp parse_bearer(header) do
    case String.split(header, " ", parts: 2) do
      [scheme, token] when token != "" ->
        if String.downcase(scheme) == "bearer", do: {:ok, token}, else: :error

      _ ->
        :error
    end
  end

  defp authenticate(conn, token, opts) do
    auth_opts = Keyword.take(opts, [:identity_module])

    case AuthenticateRequest.execute(token, auth_opts) do
      {:ok, %{workspace_id: workspace_id, user_id: user_id}} ->
        conn
        |> assign(:workspace_id, workspace_id)
        |> assign(:user_id, user_id)

      {:error, _reason} ->
        unauthorized(conn, "Invalid or expired API key")
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized", message: message}))
    |> halt()
  end
end

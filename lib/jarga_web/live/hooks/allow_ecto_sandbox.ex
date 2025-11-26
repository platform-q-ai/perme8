defmodule JargaWeb.Live.Hooks.AllowEctoSandbox do
  @moduledoc """
  LiveView hook to allow Ecto sandbox for Wallaby tests.

  This ensures database transactions are shared between the test process
  and the LiveView process handling WebSocket connections.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Phoenix.Ecto.SQL.Sandbox

  def on_mount(:default, _params, _session, socket) do
    allow_ecto_sandbox(socket)
    {:cont, socket}
  end

  defp allow_ecto_sandbox(socket) do
    %{assigns: %{phoenix_ecto_sandbox: metadata}} =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        # Get sandbox metadata from x_headers
        # The Phoenix.Ecto.SQL.Sandbox plug sets this header
        if connected?(socket) do
          get_connect_info(socket, :x_headers)
          |> List.keyfind("x-session-id", 0)
          |> case do
            {_, metadata} -> metadata
            nil -> nil
          end
        end
      end)

    # Only allow sandbox access if metadata exists and we're in test environment
    # This prevents errors when LiveView processes start during test teardown
    if metadata && Application.get_env(:jarga, :sandbox) do
      # Pass the Repo, not the Sandbox module
      Sandbox.allow(metadata, Jarga.Repo)
    end

    socket
  end
end

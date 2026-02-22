defmodule AgentsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :agents_web

  @session_options [
    store: :cookie,
    key: "_agents_web_key",
    signing_salt: "aSe55i0n",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:x_headers, session: @session_options]],
    longpoll: [connect_info: [:x_headers, session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :agents_web,
    gzip: not code_reloading?,
    only: AgentsWeb.static_paths()
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AgentsWeb.Router)
end

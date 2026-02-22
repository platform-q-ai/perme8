defmodule AgentsWeb.Router do
  use AgentsWeb, :router

  import AgentsWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AgentsWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  scope "/", AgentsWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :sessions,
      on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
      live("/sessions", SessionsLive.Index, :index)
    end
  end
end

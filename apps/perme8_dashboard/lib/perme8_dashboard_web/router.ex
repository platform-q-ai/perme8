defmodule Perme8DashboardWeb.Router do
  use Perme8DashboardWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Perme8DashboardWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", Perme8DashboardWeb do
    pipe_through(:browser)

    get("/health", HealthController, :index)
  end
end

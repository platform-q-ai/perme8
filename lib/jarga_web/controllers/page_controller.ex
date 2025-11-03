defmodule JargaWeb.PageController do
  use JargaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

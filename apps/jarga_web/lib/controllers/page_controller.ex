defmodule JargaWeb.PageController do
  use JargaWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      redirect(conn, to: ~p"/app")
    else
      render(conn, :home, layout: {JargaWeb.Layouts, :app})
    end
  end
end

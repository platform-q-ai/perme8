defmodule Perme8DashboardWeb.ErrorHTML do
  use Perme8DashboardWeb, :html

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

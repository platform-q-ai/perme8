defmodule Perme8DashboardWeb.Layouts do
  @moduledoc """
  Layout components for Perme8Dashboard.
  """
  use Perme8DashboardWeb, :html

  import Perme8DashboardWeb.TabComponents

  embed_templates("layouts/*")
end

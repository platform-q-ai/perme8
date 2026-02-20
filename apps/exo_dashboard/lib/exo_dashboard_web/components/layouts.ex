defmodule ExoDashboardWeb.Layouts do
  @moduledoc """
  Layout components for ExoDashboard.
  """
  use ExoDashboardWeb, :html

  embed_templates("layouts/*")

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end

defmodule ChatWeb do
  @moduledoc """
  The entrypoint for defining the Chat web interface.
  """

  use Boundary,
    deps: [Chat, Identity, Agents, Perme8.Events],
    exports: [
      ChatLive.Panel,
      ChatLive.MessageHandlers
    ]

  use Phoenix.Component

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  @doc """
  Minimal icon component for chat_web.
  Duplicated from JargaWeb.CoreComponents to avoid circular dependency.
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: "size-4")

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "lucide-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import ChatWeb, only: [icon: 1]

      # Common modules
      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

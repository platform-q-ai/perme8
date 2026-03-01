defmodule ChatWeb do
  @moduledoc """
  The entrypoint for defining the Chat web interface.
  """

  use Boundary,
    deps: [Chat, Identity, Agents, Perme8.Events],
    exports: []

  def live_component do
    quote do
      use Phoenix.LiveComponent
    end
  end

  def html do
    quote do
      use Phoenix.Component
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

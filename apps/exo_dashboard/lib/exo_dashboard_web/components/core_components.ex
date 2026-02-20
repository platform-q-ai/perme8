defmodule ExoDashboardWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for ExoDashboard.

  Minimal set of components needed for the dashboard.
  """
  use Phoenix.Component
  use Gettext, backend: ExoDashboardWeb.Gettext

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages to display")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      data-flash
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
  """
  attr(:rest, :global, include: ~w(href navigate patch method download name value disabled type))
  attr(:class, :any, default: nil)
  attr(:variant, :string, default: nil)
  attr(:size, :string, default: nil)
  slot(:inner_block, required: true)

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "ghost" => "btn-ghost",
      "secondary" => "btn-secondary",
      "accent" => "btn-accent",
      nil => "btn-primary btn-soft"
    }

    sizes = %{
      "xs" => "btn-xs",
      "sm" => "btn-sm",
      "md" => "",
      "lg" => "btn-lg",
      nil => ""
    }

    assigns =
      assign_new(assigns, :computed_class, fn ->
        [
          "btn",
          Map.get(variants, assigns[:variant]),
          Map.get(sizes, assigns[:size]),
          assigns[:class]
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders a header with title.
  """
  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/"}>Back to features</.back>
  """
  attr(:navigate, :any, required: true)
  slot(:inner_block, required: true)

  def back(assigns) do
    ~H"""
    <div class="mt-4">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-base-content/70 hover:text-base-content"
      >
        <.icon name="hero-arrow-left" class="size-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr(:name, :string, required: true)
  attr(:class, :any, default: "size-4")

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(ExoDashboardWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ExoDashboardWeb.Gettext, "errors", msg, opts)
    end
  end
end

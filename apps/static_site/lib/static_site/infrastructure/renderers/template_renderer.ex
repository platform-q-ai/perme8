defmodule StaticSite.Infrastructure.Renderers.TemplateRenderer do
  @moduledoc """
  Template renderer using EEx.
  """

  @doc """
  Renders a template with given assigns.
  """
  @spec render(String.t(), map(), keyword()) :: String.t()
  def render(template, assigns, _opts \\ []) do
    # Preprocess template to replace render_partial calls
    processed_template = preprocess_partials(template)
    EEx.eval_string(processed_template, assigns: assigns)
  end

  @doc """
  Renders a template from a file.
  """
  @spec render_from_file(String.t(), map(), keyword()) :: String.t()
  def render_from_file(template_path, assigns, opts \\ []) do
    case File.read(template_path) do
      {:ok, template} -> render(template, assigns, opts)
      {:error, reason} -> {:error, "Failed to read template: #{inspect(reason)}"}
    end
  end

  @doc """
  Renders a layout with content slot.
  """
  @spec render_layout(String.t(), String.t(), map(), keyword()) :: String.t()
  def render_layout(layout, content, assigns, _opts \\ []) do
    # Preprocess template to replace render_partial calls
    processed_layout = preprocess_partials(layout)
    assigns_with_content = Map.put(assigns, :content, content)
    EEx.eval_string(processed_layout, assigns: assigns_with_content)
  end

  # Private Functions

  # Preprocesses template to replace render_partial calls with actual partial content
  defp preprocess_partials(template) do
    # Find all render_partial calls using regex
    # Pattern: <%= render_partial("partial_name", assigns) %>
    # Also handles: <%= render_partial("partial_name",assigns) %>
    regex = ~r/<%= render_partial\("([^"]+)",\s*assigns\) ?%>/

    Regex.replace(regex, template, fn _, _partial_name ->
      # Return empty since we don't have access to layouts_dir here
      # This is a limitation - partials only work with LayoutResolver.render_with_layout
      ""
    end)
  end
end

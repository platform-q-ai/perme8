defmodule Alkali.Domain.Entities.Asset do
  @moduledoc """
  Asset entity represents a static asset file (CSS, JS, or binary).

  Assets can be fingerprinted for cache busting.
  """

  @type asset_type :: :css | :js | :binary
  @type t :: %__MODULE__{
          original_path: String.t(),
          output_path: String.t(),
          fingerprint: String.t() | nil,
          type: asset_type(),
          content: binary() | nil
        }

  defstruct [:original_path, :output_path, :fingerprint, :type, :content]

  @doc """
  Creates a new Asset.

  ## Examples

      iex> Asset.new(%{original_path: "static/css/app.css", output_path: "_site/css/app.css", type: :css})
      %Asset{original_path: "static/css/app.css", output_path: "_site/css/app.css", type: :css}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Adds fingerprint to asset and updates output path.

  Inserts fingerprint before file extension in output path.

  ## Examples

      iex> asset = %Asset{output_path: "_site/css/app.css"}
      iex> Asset.with_fingerprint(asset, "abc123")
      %Asset{output_path: "_site/css/app-abc123.css", fingerprint: "abc123"}
  """
  @spec with_fingerprint(t(), String.t()) :: t()
  def with_fingerprint(%__MODULE__{output_path: output_path} = asset, fingerprint) do
    # Take only first 8 characters of fingerprint for shorter filenames
    short_fingerprint = String.slice(fingerprint, 0, 8)

    # Insert fingerprint before file extension
    updated_output_path = insert_fingerprint_in_path(output_path, short_fingerprint)

    %{asset | fingerprint: fingerprint, output_path: updated_output_path}
  end

  # Private Helpers

  defp insert_fingerprint_in_path(path, fingerprint) do
    ext = Path.extname(path)
    base = Path.rootname(path)
    "#{base}-#{fingerprint}#{ext}"
  end
end

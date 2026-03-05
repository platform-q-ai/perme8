defmodule Agents.Sessions.Domain.Policies.ImagePolicy do
  @moduledoc """
  Pure business rules for container image classification.

  Determines whether an image is a lightweight discussion-only image,
  what resource limits to apply, and whether it should bypass the build queue.

  Contains no I/O, no infrastructure dependencies. All functions are pure.
  """

  @light_images ["perme8-opencode-light"]
  @default_limits %{memory: "2g", cpus: "2"}
  @light_limits %{memory: "512m", cpus: "1"}

  @doc "Returns the list of light image names."
  @spec light_image_names() :: [String.t()]
  def light_image_names, do: @light_images

  @doc "Returns true if the given image is a lightweight discussion-only image."
  @spec light_image?(String.t() | nil) :: boolean()
  def light_image?(nil), do: false
  def light_image?(image) when is_binary(image), do: image in @light_images

  @doc "Returns true if tasks using this image should bypass the build queue."
  @spec bypasses_queue?(String.t() | nil) :: boolean()
  def bypasses_queue?(image), do: light_image?(image)

  @doc "Returns the Docker resource limits for the given image."
  @spec resource_limits(String.t() | nil) :: %{memory: String.t(), cpus: String.t()}
  def resource_limits(image) do
    if light_image?(image), do: @light_limits, else: @default_limits
  end
end

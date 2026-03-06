defmodule Agents.Sessions.Domain.Entities.LaneEntry do
  @moduledoc """
  Pure domain entity representing a task entry inside a queue lane.
  """

  alias Agents.Sessions.Domain.Policies.ImagePolicy

  @type warm_state :: :cold | :warming | :warm | :hot
  @type lane :: :processing | :warm | :cold | :awaiting_feedback | :retry_pending

  @type t :: %__MODULE__{
          task_id: String.t() | nil,
          instruction: String.t() | nil,
          status: String.t() | nil,
          lane: lane() | nil,
          container_id: String.t() | nil,
          warm_state: warm_state(),
          queue_position: non_neg_integer() | nil,
          retry_count: non_neg_integer(),
          error: String.t() | nil,
          queued_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          image: String.t() | nil
        }

  defstruct [
    :task_id,
    :instruction,
    :status,
    :lane,
    :container_id,
    :queue_position,
    :error,
    :queued_at,
    :started_at,
    :image,
    retry_count: 0,
    warm_state: :cold
  ]

  @doc """
  Creates a lane entry from attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns true when the entry has a warm or hot container.
  """
  @spec warm?(t()) :: boolean()
  def warm?(%__MODULE__{warm_state: warm_state}) do
    warm_state in [:warm, :hot]
  end

  @doc """
  Returns true when the entry has a cold container state.
  """
  @spec cold?(t()) :: boolean()
  def cold?(%__MODULE__{warm_state: :cold}), do: true
  def cold?(%__MODULE__{}), do: false

  @doc """
  Returns true when the entry uses a lightweight container image.

  Delegates to `ImagePolicy` as the single source of truth for image classification.
  """
  @spec light_image?(t()) :: boolean()
  def light_image?(%__MODULE__{image: image}), do: ImagePolicy.light_image?(image)
end

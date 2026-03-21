defmodule Agents.Pipeline.Domain.Entities.StageResult do
  @moduledoc "Value object describing a single executed stage outcome."

  @type status :: :passed | :failed

  @type t :: %__MODULE__{
          stage_id: String.t(),
          status: status(),
          output: String.t() | nil,
          exit_code: integer() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          failure_reason: String.t() | nil,
          metadata: map()
        }

  defstruct [
    :stage_id,
    :status,
    :output,
    :exit_code,
    :started_at,
    :completed_at,
    :failure_reason,
    metadata: %{}
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{
      "stage_id" => result.stage_id,
      "status" => Atom.to_string(result.status),
      "output" => result.output,
      "exit_code" => result.exit_code,
      "started_at" => encode_datetime(result.started_at),
      "completed_at" => encode_datetime(result.completed_at),
      "failure_reason" => result.failure_reason,
      "metadata" => result.metadata || %{}
    }
  end

  @spec from_map(map()) :: t()
  def from_map(attrs) when is_map(attrs) do
    %__MODULE__{
      stage_id: Map.get(attrs, "stage_id") || Map.get(attrs, :stage_id),
      status:
        attrs
        |> Map.get("status", Map.get(attrs, :status, "failed"))
        |> to_status(),
      output: Map.get(attrs, "output") || Map.get(attrs, :output),
      exit_code: Map.get(attrs, "exit_code") || Map.get(attrs, :exit_code),
      started_at: decode_datetime(Map.get(attrs, "started_at") || Map.get(attrs, :started_at)),
      completed_at:
        decode_datetime(Map.get(attrs, "completed_at") || Map.get(attrs, :completed_at)),
      failure_reason: Map.get(attrs, "failure_reason") || Map.get(attrs, :failure_reason),
      metadata: Map.get(attrs, "metadata") || Map.get(attrs, :metadata) || %{}
    }
  end

  defp to_status(status) when status in [:passed, :failed], do: status
  defp to_status("passed"), do: :passed
  defp to_status(_), do: :failed

  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp decode_datetime(nil), do: nil
  defp decode_datetime(%DateTime{} = value), do: value

  defp decode_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end
end

defmodule Agents.Pipeline.Domain.Policies.WarmPoolPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Stage
  alias Agents.Pipeline.Domain.Policies.WarmPoolPolicy

  test "builds a policy from a warm-pool stage" do
    stage =
      Stage.new(%{
        id: "warm-pool",
        type: "warm_pool",
        schedule: %{"cron" => "*/5 * * * *"},
        config: %{
          "warm_pool" => %{
            "target_count" => 3,
            "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
            "readiness" => %{"strategy" => "command_success", "required_step" => "prewarm"}
          }
        }
      })

    assert {:ok, policy} = WarmPoolPolicy.from_stage(stage)
    assert policy.stage_id == "warm-pool"
    assert policy.cron == "*/5 * * * *"
    assert policy.target_count == 3
    assert policy.image == "ghcr.io/platform-q-ai/perme8-runtime:latest"
    assert policy.readiness_criteria["required_step"] == "prewarm"
  end

  test "calculates shortage and replenishment requirement" do
    policy = %WarmPoolPolicy{
      stage_id: "warm-pool",
      cron: "*/5 * * * *",
      target_count: 3,
      image: "img",
      readiness_criteria: %{}
    }

    assert WarmPoolPolicy.shortage(policy, 1) == 2
    assert WarmPoolPolicy.shortage(policy, 5) == 0
    assert WarmPoolPolicy.replenishment_required?(policy, 1)
    refute WarmPoolPolicy.replenishment_required?(policy, 3)
  end

  test "rejects missing config" do
    stage = Stage.new(%{id: "warm-pool", type: "warm_pool", schedule: %{}, config: %{}})
    assert {:error, :missing_cron} = WarmPoolPolicy.from_stage(stage)
  end
end

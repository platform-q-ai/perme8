defmodule JargaWeb.TelemetryTest do
  use ExUnit.Case, async: true

  alias JargaWeb.Telemetry

  describe "Telemetry" do
    test "metrics/0 returns a list of telemetry metrics" do
      metrics = Telemetry.metrics()
      assert is_list(metrics)
      assert match?([_ | _], metrics)
    end

    test "start_link/1 handles supervisor start" do
      # Telemetry is already started by the application, so we expect either
      # :ok or already_started
      result = Telemetry.start_link([])

      case result do
        {:ok, pid} ->
          assert Process.alive?(pid)

        {:error, {:already_started, pid}} ->
          assert Process.alive?(pid)
      end
    end
  end
end

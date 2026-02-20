defmodule ExoDashboard.TestRuns.Infrastructure.NdjsonWatcherTest do
  use ExUnit.Case, async: false

  alias ExoDashboard.TestRuns.Infrastructure.NdjsonWatcher

  setup do
    tmp_dir = System.tmp_dir!()
    ndjson_path = Path.join(tmp_dir, "test_watcher_#{:rand.uniform(1_000_000)}.ndjson")
    # Create empty file
    File.write!(ndjson_path, "")
    on_exit(fn -> File.rm(ndjson_path) end)
    %{path: ndjson_path}
  end

  describe "watching a file" do
    test "broadcasts parsed JSON lines as they appear", %{path: path} do
      test_pid = self()

      callback = fn envelope ->
        send(test_pid, {:envelope, envelope})
      end

      {:ok, watcher} = NdjsonWatcher.start_link(path: path, callback: callback, poll_interval: 50)

      # Write a JSON line to the file
      File.write!(path, ~s|{"testRunStarted":{"timestamp":"2024-01-01T00:00:00Z"}}\n|, [:append])

      # Wait for the watcher to pick it up
      assert_receive {:envelope, %{"testRunStarted" => _}}, 1000

      GenServer.stop(watcher)
    end

    test "handles malformed JSON gracefully", %{path: path} do
      test_pid = self()

      callback = fn envelope ->
        send(test_pid, {:envelope, envelope})
      end

      {:ok, watcher} = NdjsonWatcher.start_link(path: path, callback: callback, poll_interval: 50)

      # Write a malformed line followed by a valid line
      File.write!(path, "not valid json\n", [:append])
      File.write!(path, ~s|{"pickle":{"id":"p-1","name":"Test"}}\n|, [:append])

      # Should still receive the valid line
      assert_receive {:envelope, %{"pickle" => _}}, 1000

      GenServer.stop(watcher)
    end

    test "stops after testRunFinished", %{path: path} do
      test_pid = self()

      callback = fn envelope ->
        send(test_pid, {:envelope, envelope})
      end

      {:ok, watcher} = NdjsonWatcher.start_link(path: path, callback: callback, poll_interval: 50)

      File.write!(path, ~s|{"testRunFinished":{"success":true}}\n|, [:append])

      assert_receive {:envelope, %{"testRunFinished" => _}}, 1000

      # Watcher should stop itself
      Process.sleep(200)
      refute Process.alive?(watcher)
    end
  end
end

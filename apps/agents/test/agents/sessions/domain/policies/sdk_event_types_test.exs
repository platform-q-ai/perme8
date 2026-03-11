defmodule Agents.Sessions.Domain.Policies.SdkEventTypesTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.SdkEventTypes

  describe "handled_types/0" do
    test "returns exactly 17 handled event types" do
      assert length(SdkEventTypes.handled_types()) == 17
    end

    test "includes all expected handled types" do
      handled = SdkEventTypes.handled_types()

      assert "server.connected" in handled
      assert "server.instance.disposed" in handled
      assert "session.created" in handled
      assert "session.updated" in handled
      assert "session.deleted" in handled
      assert "session.status" in handled
      assert "session.idle" in handled
      assert "session.compacted" in handled
      assert "session.diff" in handled
      assert "session.error" in handled
      assert "message.updated" in handled
      assert "message.removed" in handled
      assert "message.part.updated" in handled
      assert "message.part.removed" in handled
      assert "permission.updated" in handled
      assert "permission.replied" in handled
      assert "file.edited" in handled
    end
  end

  describe "ignored_types/0" do
    test "returns exactly 15 ignored event types" do
      assert length(SdkEventTypes.ignored_types()) == 15
    end

    test "includes all expected ignored types" do
      ignored = SdkEventTypes.ignored_types()

      assert "installation.updated" in ignored
      assert "installation.update-available" in ignored
      assert "lsp.client.diagnostics" in ignored
      assert "lsp.updated" in ignored
      assert "todo.updated" in ignored
      assert "command.executed" in ignored
      assert "vcs.branch.updated" in ignored
      assert "tui.prompt.append" in ignored
      assert "tui.command.execute" in ignored
      assert "tui.toast.show" in ignored
      assert "pty.created" in ignored
      assert "pty.updated" in ignored
      assert "pty.exited" in ignored
      assert "pty.deleted" in ignored
      assert "file.watcher.updated" in ignored
    end
  end

  describe "all_types/0" do
    test "returns exactly 32 event types" do
      assert length(SdkEventTypes.all_types()) == 32
    end

    test "is the union of handled and ignored types" do
      assert Enum.sort(SdkEventTypes.all_types()) ==
               Enum.sort(SdkEventTypes.handled_types() ++ SdkEventTypes.ignored_types())
    end
  end

  describe "handled?/1" do
    test "returns true for all handled types" do
      for type <- SdkEventTypes.handled_types() do
        assert SdkEventTypes.handled?(type), "expected #{type} to be handled"
      end
    end

    test "returns false for all ignored types" do
      for type <- SdkEventTypes.ignored_types() do
        refute SdkEventTypes.handled?(type), "expected #{type} to NOT be handled"
      end
    end

    test "returns false for unknown event types" do
      refute SdkEventTypes.handled?("unknown.event")
      refute SdkEventTypes.handled?("")
      refute SdkEventTypes.handled?(nil)
    end
  end

  describe "disjoint sets" do
    test "handled and ignored types have no overlap" do
      handled = MapSet.new(SdkEventTypes.handled_types())
      ignored = MapSet.new(SdkEventTypes.ignored_types())

      assert MapSet.disjoint?(handled, ignored)
    end
  end
end

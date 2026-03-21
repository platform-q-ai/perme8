defmodule AgentsWeb.DashboardLive.TaskExecutionHelpersPrTabTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  test "session_tabs/1 includes pr tab when linked PR exists" do
    tabs = TaskExecutionHelpers.session_tabs(true)

    assert Enum.any?(tabs, &(&1.id == "chat"))
    assert Enum.any?(tabs, &(&1.id == "ticket"))
    assert Enum.any?(tabs, &(&1.id == "pr"))
  end

  test "session_tabs/1 excludes pr tab when linked PR does not exist" do
    tabs = TaskExecutionHelpers.session_tabs(false)

    assert Enum.any?(tabs, &(&1.id == "chat"))
    assert Enum.any?(tabs, &(&1.id == "ticket"))
    refute Enum.any?(tabs, &(&1.id == "pr"))
  end

  test "resolve_active_tab/3 accepts pr when available" do
    assert "pr" == TaskExecutionHelpers.resolve_active_tab(%{"tab" => "pr"}, true, true)
  end

  test "resolve_active_tab/3 falls back to chat when pr is unavailable" do
    assert "chat" == TaskExecutionHelpers.resolve_active_tab(%{"tab" => "pr"}, true, false)
  end
end

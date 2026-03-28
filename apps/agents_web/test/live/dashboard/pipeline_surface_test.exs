defmodule AgentsWeb.DashboardLive.PipelineSurfaceTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Agents.Test.WorkspacesFixtures

  setup :register_and_log_in_user

  test "does not render the inline pipeline configuration editor for workspace owners", %{
    conn: conn,
    user: user
  } do
    WorkspacesFixtures.workspace_fixture(user)

    {:ok, view, _html} = live(conn, ~p"/sessions")

    refute has_element?(view, "[data-testid='pipeline-editor']")
    assert has_element?(view, "[data-testid='pipeline-management-note']")
  end
end

defmodule AgentsWeb.DashboardLive.PipelineEditorTest do
  use AgentsWeb.ConnCase, async: true

  alias Agents.Test.WorkspacesFixtures

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "hides the pipeline editor for users without operator access", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions")

    refute has_element?(view, "[data-testid='pipeline-editor']")
  end

  test "shows the pipeline editor for workspace owners", %{conn: conn, user: user} do
    WorkspacesFixtures.workspace_fixture(user)

    {:ok, view, _html} = live(conn, ~p"/sessions")

    assert has_element?(view, "[data-testid='pipeline-editor']")
  end

  test "renders editable pipeline stage cards in fixture order", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions?fixture=pipeline_configuration_editor_loaded")

    assert has_element?(view, "[data-testid='pipeline-stage-cards']")
    assert has_element?(view, "[data-testid='pipeline-stage-card-warm-pool']")

    cards_text = render(view)
    assert cards_text =~ "Ready"
    assert cards_text =~ "In Progress"
    assert cards_text =~ "In Review"
    assert cards_text =~ "Warm Pool"
  end

  test "edits step fields and updates staged preview", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions?fixture=pipeline_configuration_editor_step_editing")

    view
    |> element("[name='step_run:1:0']")
    |> render_change(%{"step_run:1:0" => "mix test"})

    view
    |> element("[name='step_timeout:1:0']")
    |> render_change(%{"step_timeout:1:0" => "600"})

    view
    |> element("[name='step_conditions:1:0']")
    |> render_change(%{"step_conditions:1:0" => "branch == main"})

    view
    |> element("[name='step_env:1:0']")
    |> render_change(%{"step_env:1:0" => "LOG_LEVEL=debug\nMIX_ENV=test"})

    preview = render(view)
    assert preview =~ "mix test"
    assert preview =~ "600"
    assert preview =~ "branch == main"
    assert preview =~ "MIX_ENV=test"
    assert preview =~ "LOG_LEVEL=debug"
  end

  test "supports add remove and reorder stage and step actions", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions?fixture=pipeline_configuration_editor_structure_editing")

    view |> element("button", "Add stage") |> render_click()

    view
    |> element("[data-testid='new-stage-name-input']")
    |> render_change(%{"new_stage_name" => "Security Scan"})

    view |> element("[data-testid='add-step-security-scan']") |> render_click()

    view
    |> element("[name='new_step_command:2']")
    |> render_change(%{"new_step_command:2" => "mix credo --strict"})

    view |> element("[data-testid='move-stage-security-scan-up']") |> render_click()
    view |> element("[data-testid='move-step-security-scan-1-down']") |> render_click()
    view |> element("[data-testid='remove-step-legacy-cleanup-1']") |> render_click()
    view |> element("[data-testid='remove-stage-legacy-cleanup']") |> render_click()

    html = render(view)
    assert html =~ "Security Scan"
    assert html =~ "mix credo --strict"
    refute html =~ "Legacy Cleanup"
  end

  test "shows validation errors on invalid save and keeps draft", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions?fixture=pipeline_configuration_editor_invalid_changes")

    view |> element("button", "Save configuration") |> render_click()

    html = render(view)
    assert html =~ "Please resolve validation errors before saving"
    assert html =~ "Changes were not saved"
    assert html =~ "staged-pipeline-preview"
  end

  test "shows success feedback on valid save", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions?fixture=pipeline_configuration_editor_valid_changes")

    view |> element("button", "Save configuration") |> render_click()

    path = :sys.get_state(view.pid).socket.assigns.pipeline_editor_path

    html = render(view)
    assert html =~ "Configuration saved"
    assert html =~ "perme8-pipeline.yml"
    assert html =~ "No staged changes"

    assert File.read!(path) =~ "mix test --trace"
  end
end

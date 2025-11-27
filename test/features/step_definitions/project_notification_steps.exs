defmodule ProjectNotificationSteps do
  @moduledoc """
  Cucumber step definitions for project notification scenarios (PubSub).

  Tests real-time project notifications broadcast via Phoenix PubSub.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import ExUnit.Assertions

  # ============================================================================
  # PUBSUB NOTIFICATION ASSERTIONS
  # ============================================================================

  step "a project created notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project creation action
    # This is typically done in a previous step like "I am viewing the project"
    # or "user is viewing workspace"

    # Verify we received the project created broadcast
    assert_receive {:project_added, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "a project updated notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project update action

    # Verify we received the project updated broadcast
    assert_receive {:project_updated, project_id, name}, 1000
    assert project_id == project.id
    assert name == project.name

    {:ok, context}
  end

  step "a project deleted notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project deletion action

    # Verify we received the project deleted broadcast
    assert_receive {:project_removed, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "user {string} should receive a project created notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_added, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "user {string} should receive a project updated notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_updated, project_id, name}, 1000
    assert project_id == project.id
    assert name == project.name

    {:ok, context}
  end

  step "user {string} should receive a project deleted notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_removed, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  # Note: "user updates workspace name" and "user updates project name" steps
  # are defined in document_pubsub_steps and are shared
end

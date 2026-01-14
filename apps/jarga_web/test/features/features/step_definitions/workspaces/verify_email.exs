defmodule Workspaces.VerifyEmailSteps do
  @moduledoc """
  Step definitions for workspace email verification and assertions.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Swoosh.TestAssertions

  # ============================================================================
  # EMAIL ASSERTIONS
  # ============================================================================

  step "an invitation email should be sent to {string}", %{args: [email]} = context do
    assert_email_sent(to: email)

    {:ok, context}
  end

  step "a notification email should be sent to {string}", %{args: [email]} = context do
    assert_email_sent(to: email)

    {:ok, context}
  end

  step "an invitation email should be queued", context do
    assert_email_sent()

    {:ok, context}
  end

  step "a notification email should be queued", context do
    assert_email_sent()

    {:ok, context}
  end

  step "the email should contain a link to join workspace {string}",
       %{args: [workspace_slug]} = context do
    assert_email_sent(fn email ->
      email_body = email.text_body || email.html_body || ""
      has_workspace_link = email_body =~ workspace_slug

      assert has_workspace_link,
             "Expected email to contain link with workspace slug '#{workspace_slug}'"

      true
    end)

    {:ok, context}
  end

  step "the email should contain a link to workspace {string}",
       %{args: [workspace_slug]} = context do
    assert_email_sent(fn email ->
      email_body = email.text_body || email.html_body || ""
      has_workspace_link = email_body =~ workspace_slug

      assert has_workspace_link,
             "Expected email to contain link with workspace slug '#{workspace_slug}'"

      true
    end)

    {:ok, context}
  end

  step "the email should contain {string}", %{args: [expected_text]} = context do
    assert_email_sent(fn email ->
      email_body = email.text_body || email.html_body || ""
      has_text = email_body =~ expected_text

      assert has_text,
             "Expected email to contain '#{expected_text}'"

      true
    end)

    {:ok, context}
  end
end

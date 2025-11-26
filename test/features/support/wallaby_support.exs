defmodule WallabySupport do
  @moduledoc """
  Cucumber hooks for Wallaby browser-based tests.

  Provides setup and teardown for @javascript scenarios that require
  actual browser interaction via ChromeDriver.
  """

  use Cucumber.Hooks
  use Wallaby.DSL
  import Wallaby.Query

    :ok
  end

  # Ensure all Wallaby sessions are cleaned up after each feature
  after_feature context do
    # Kill any remaining ChromeDriver processes
    # This is a safety net to prevent orphaned Chromium instances
    try do
      # More aggressive cleanup
      System.cmd("pkill", ["-9", "-f", "chromedriver"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "chrome.*--remote-debugging"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "wallaby_chromedriver"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "chrome.*--test-type"], stderr_to_stdout: true)
    rescue
      _ -> :ok
    end

    :ok
  end

  # Final cleanup after all tests
  after_all context do
    # Kill any remaining ChromeDriver processes
    try do
      System.cmd("pkill", ["-9", "-f", "chromedriver"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "chrome.*--remote-debugging"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "wallaby_chromedriver"], stderr_to_stdout: true)
      System.cmd("pkill", ["-9", "-f", "chrome.*--test-type"], stderr_to_stdout: true)
      # Wait for processes to fully terminate
      Process.sleep(1000)
    rescue
      _ -> :ok
    end

    # Also try to end any existing sessions
    try do
      Wallaby.end_session(nil)
    rescue
      _ -> :ok
    end

    :ok
  end

  # Set up Ecto Sandbox and browser session for @javascript scenarios
  before_scenario "@javascript", context do
    # Set up Ecto Sandbox with proper mode for Wallaby
    # Check if sandbox is already checked out (from Background steps)
    case Ecto.Adapters.SQL.Sandbox.checkout(Jarga.Repo) do
      :ok -> :ok
      {:already, :owner} -> :ok
    end

    # IMPORTANT: Always set shared mode, even if Background steps already checked out
    # This ensures all processes (including LiveView) can access the DB
    Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})

    # Get sandbox metadata for Wallaby session
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Jarga.Repo, self())

    # Start a Wallaby session with sandbox metadata
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    # NOTE: We don't log in here because the user doesn't exist yet.
    # The "I am logged in as a user" step will handle authentication.

    {:ok, Map.put(context, :session, session)}
  end

  # Clean up browser session and Ecto Sandbox after @javascript scenarios
  after_scenario "@javascript", context do
    # End Wallaby session if it exists
    if session = context[:session] do
      Wallaby.end_session(session)
    end

    # Checkin Ecto Sandbox (only if we're the owner)
    # The scenario steps might have already checked in
    try do
      Ecto.Adapters.SQL.Sandbox.checkin(Jarga.Repo)
    rescue
      RuntimeError -> :ok
    end

    :ok
  end

  # Helper to log in a user via the browser (used by step definitions)
  def login_user(session, user, password \\ "hello world!") do
    # Use the real login flow to authenticate
    session
    |> Wallaby.Browser.visit("/users/log-in")
    |> Wallaby.Browser.assert_has(css("#login_form_password"))
    |> Wallaby.Browser.fill_in(css("#login_form_password_email"), with: user.email)
    |> Wallaby.Browser.fill_in(css("#login_form_password_password"), with: password)
    |> Wallaby.Browser.click(button("Log in and stay logged in"))
    # Wait for redirect and authentication to complete
    |> then(fn session ->
      Process.sleep(1000)
      session
    end)
  end
end

defmodule Jarga.Accounts.ApiKeys.Helpers do
  @moduledoc """
  Shared helper functions for API Key step definitions.

  Provides reusable functions for:
  - LiveView interactions (clicking buttons, submitting forms)
  - Token extraction from HTML responses
  - API key lookup and context management
  """

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Accounts

  # ============================================================================
  # SANDBOX HELPERS
  # ============================================================================

  def ensure_sandbox_checkout do
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end
  end

  # ============================================================================
  # WORKSPACE ACCESS PARSING
  # ============================================================================

  def build_workspace_owners(table_data, users) do
    Enum.reduce(table_data, %{}, fn row, acc ->
      slug = row["Slug"]
      owner_email = row["Owner"]
      owner = Map.get(users, owner_email)
      Map.put(acc, slug, owner)
    end)
  end

  def parse_workspace_access(nil), do: []
  def parse_workspace_access(""), do: []

  def parse_workspace_access(workspace_access_str) do
    workspace_access_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  # ============================================================================
  # LIVEVIEW INTERACTION HELPERS
  # ============================================================================

  @doc """
  Clicks the "New API Key" button to open the create modal.
  """
  def click_create_button(view) do
    view
    |> element("div.flex.items-center.justify-between button[phx-click='show_create_modal']")
    |> render_click()
  end

  @doc """
  Clicks the edit button for a specific API key.
  """
  def click_edit_button(view, api_key_id) do
    view
    |> element("button[phx-click='edit_key'][phx-value-id='#{api_key_id}']")
    |> render_click()
  end

  @doc """
  Clicks the revoke button for a specific API key.
  """
  def click_revoke_button(view, api_key_id) do
    view
    |> element("button[phx-click='revoke_key'][phx-value-id='#{api_key_id}']")
    |> render_click()
  end

  @doc """
  Submits the create API key form with the given data.
  Returns the rendered HTML after submission.
  """
  def submit_create_form(view, form_data) do
    view
    |> form("#create_form", form_data)
    |> render_submit(event: "create_key")
  end

  @doc """
  Submits the edit API key form with the given data.
  Returns the rendered HTML after submission.
  """
  def submit_edit_form(view, form_data \\ %{}) do
    view
    |> form("#edit_form", form_data)
    |> render_submit()
  end

  # ============================================================================
  # TOKEN EXTRACTION
  # ============================================================================

  @doc """
  Extracts the plain API key token from HTML response.
  Tokens are 64 characters of URL-safe Base64 (a-z, A-Z, 0-9, -, _).
  Returns nil if no token found.
  """
  def extract_token_from_html(html) do
    case Regex.run(~r/[a-zA-Z0-9_-]{64}/, html) do
      [token] -> token
      nil -> nil
    end
  end

  # ============================================================================
  # API KEY LOOKUP
  # ============================================================================

  @doc """
  Fetches an API key by name for a user.
  Returns the API key or nil if not found.
  """
  def fetch_api_key_by_name(user_id, name) do
    {:ok, api_keys} = Accounts.list_api_keys(user_id)
    Enum.find(api_keys, fn k -> k.name == name end)
  end

  @doc """
  Fetches an API key by ID for a user.
  Returns the API key or nil if not found.
  """
  def fetch_api_key_by_id(user_id, api_key_id) do
    {:ok, api_keys} = Accounts.list_api_keys(user_id)
    Enum.find(api_keys, fn k -> k.id == api_key_id end)
  end

  # ============================================================================
  # RESULT CHECKING
  # ============================================================================

  @doc """
  Checks if API key creation was successful by looking for the name in HTML.
  """
  def creation_successful?(html, name), do: html =~ name

  @doc """
  Checks if API key revocation was successful.
  """
  def revocation_successful?(html) do
    html =~ "revoked successfully" or html =~ "badge-error"
  end
end

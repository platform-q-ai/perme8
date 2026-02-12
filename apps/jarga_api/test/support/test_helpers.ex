defmodule JargaApi.Test.Helpers do
  @moduledoc """
  Shared helper functions for API step definitions.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.AccountsFixtures, Identity],
    exports: []

  alias Ecto.Adapters.SQL.Sandbox

  def ensure_sandbox_checkout do
    # Checkout both repos for dual-repo setup
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end
  end

  @doc """
  Builds a connection with sandbox metadata header for API tests.

  This is critical for API tests using Phoenix.ConnTest - without the sandbox
  metadata header, the API endpoint runs in a different DB connection and
  can't see data created in the test process.

  Includes metadata for both Jarga.Repo and Identity.Repo for dual-repo setup.
  """
  def build_conn_with_sandbox do
    # Get sandbox metadata for both repos
    jarga_metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Jarga.Repo, self())
    identity_metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Identity.Repo, self())

    # Combine metadata for both repos
    combined_metadata = Map.merge(jarga_metadata, identity_metadata)
    encoded_metadata = Phoenix.Ecto.SQL.Sandbox.encode_metadata(combined_metadata)

    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("user-agent", encoded_metadata)
  end

  @doc """
  Parses workspace access from comma-separated string.
  """
  def parse_workspace_access(nil), do: []
  def parse_workspace_access(""), do: []

  def parse_workspace_access(workspace_access_str) do
    workspace_access_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  @doc """
  Creates an API key fixture without workspace membership validation.
  Delegates to `Jarga.AccountsFixtures.api_key_fixture_without_validation/2`.
  Returns {api_key_entity, plain_token}.
  """
  def create_api_key_fixture(user_id, attrs) do
    Jarga.AccountsFixtures.api_key_fixture_without_validation(user_id, attrs)
  end

  @doc """
  Gets workspace from context by slug.
  """
  def get_workspace_by_slug(context, slug) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug) ||
      if(context[:workspace] && context[:workspace].slug == slug, do: context[:workspace])
  end

  @doc """
  Translates any known slugs (documents, projects, etc.) from feature-file slugs
  to actual DB slugs in a URL path.

  Uses the `slug_translations` map stored in context by setup steps. Each entry
  maps a feature-file slug to its actual database slug.

  ## Example

      context = %{slug_translations: %{"my-doc" => "my-doc-abc123"}}
      translate_known_slugs("/api/workspaces/ws/documents/my-doc", context)
      #=> "/api/workspaces/ws/documents/my-doc-abc123"

  """
  def translate_known_slugs(path, context) do
    slug_translations = context[:slug_translations] || %{}

    Enum.reduce(slug_translations, path, fn {feature_slug, actual_slug}, acc ->
      # Only translate when the feature slug appears as a path segment
      # (preceded by "/" and followed by "/" or end of string)
      String.replace(acc, "/" <> feature_slug, "/" <> actual_slug)
    end)
  end
end

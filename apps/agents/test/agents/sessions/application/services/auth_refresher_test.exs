defmodule Agents.Sessions.Application.Services.AuthRefresherTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.Services.AuthRefresher

  # A simple stub module for file reading
  defmodule FakeFile do
    def read(:valid_path) do
      {:ok,
       Jason.encode!(%{
         "anthropic" => %{
           "type" => "oauth",
           "access" => "fresh-token",
           "expires" => 9_999_999_999_999
         },
         "openrouter" => %{"type" => "api", "key" => "sk-or-test"}
       })}
    end

    def read(:single_provider_path) do
      {:ok, Jason.encode!(%{"anthropic" => %{"type" => "api", "key" => "sk-ant-new"}})}
    end

    def read(:invalid_json_path) do
      {:ok, "not valid json {{{"}
    end

    def read(:missing_path) do
      {:error, :enoent}
    end
  end

  # A stub opencode client that records calls
  defmodule SuccessClient do
    def set_auth(_base_url, _provider_id, _credentials, _opts) do
      {:ok, true}
    end

    def list_providers(_base_url, _opts) do
      {:ok, %{"all" => [], "connected" => ["anthropic", "openrouter"], "default" => %{}}}
    end
  end

  defmodule PartialFailClient do
    def set_auth(_base_url, "anthropic", _credentials, _opts) do
      {:ok, true}
    end

    def set_auth(_base_url, "openrouter", _credentials, _opts) do
      {:error, {:http_error, 500, %{"error" => "internal"}}}
    end

    def list_providers(_base_url, _opts) do
      {:ok, %{"connected" => ["anthropic"]}}
    end
  end

  defmodule FailClient do
    def list_providers(_base_url, _opts) do
      {:error, :econnrefused}
    end
  end

  describe "refresh_auth/3" do
    test "refreshes all providers from auth.json" do
      assert {:ok, ["anthropic", "openrouter"]} =
               AuthRefresher.refresh_auth(
                 "http://localhost:4096",
                 SuccessClient,
                 auth_json_path: :valid_path,
                 file_reader: FakeFile
               )
    end

    test "refreshes a single provider" do
      assert {:ok, ["anthropic"]} =
               AuthRefresher.refresh_auth(
                 "http://localhost:4096",
                 SuccessClient,
                 auth_json_path: :single_provider_path,
                 file_reader: FakeFile
               )
    end

    test "returns provider-level failures with error details when some providers fail" do
      assert {:error, {:auth_refresh_failed, failures}} =
               AuthRefresher.refresh_auth(
                 "http://localhost:4096",
                 PartialFailClient,
                 auth_json_path: :valid_path,
                 file_reader: FakeFile
               )

      assert Enum.any?(failures, fn failure ->
               failure.provider == "openrouter" and
                 failure.reason == {:http_error, 500, %{"error" => "internal"}}
             end)
    end

    test "returns error when auth.json is missing" do
      assert {:error, :enoent} =
               AuthRefresher.refresh_auth(
                 "http://localhost:4096",
                 SuccessClient,
                 auth_json_path: :missing_path,
                 file_reader: FakeFile
               )
    end

    test "returns error when auth.json contains invalid JSON" do
      assert {:error, %Jason.DecodeError{}} =
               AuthRefresher.refresh_auth(
                 "http://localhost:4096",
                 SuccessClient,
                 auth_json_path: :invalid_json_path,
                 file_reader: FakeFile
               )
    end
  end

  describe "connected_providers/3" do
    test "returns connected provider IDs" do
      assert {:ok, ["anthropic", "openrouter"]} =
               AuthRefresher.connected_providers(
                 "http://localhost:4096",
                 SuccessClient
               )
    end

    test "returns partial list when some disconnected" do
      assert {:ok, ["anthropic"]} =
               AuthRefresher.connected_providers(
                 "http://localhost:4096",
                 PartialFailClient
               )
    end

    test "returns error on connection failure" do
      assert {:error, :econnrefused} =
               AuthRefresher.connected_providers(
                 "http://localhost:4096",
                 FailClient
               )
    end
  end
end

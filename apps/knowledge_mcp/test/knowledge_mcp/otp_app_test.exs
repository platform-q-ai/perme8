defmodule KnowledgeMcp.OtpAppTest do
  @moduledoc """
  Tests for the KnowledgeMcp OTP application supervision tree.

  Verifies that the application starts successfully and that key
  processes (Registry, MCP Server) are running.
  """
  use ExUnit.Case, async: false

  alias KnowledgeMcp.Infrastructure.Mcp.Server

  describe "application supervision tree" do
    test "application is started" do
      started_apps = Application.started_applications()
      app_names = Enum.map(started_apps, fn {name, _, _} -> name end)

      assert :knowledge_mcp in app_names
    end

    test "Hermes.Server.Registry is running" do
      # The Registry is a process — verify it's alive
      assert Process.whereis(Hermes.Server.Registry) != nil
    end

    test "MCP Server supervisor is running" do
      # Hermes registers the server supervisor via the Registry
      pid = Hermes.Server.Registry.whereis_supervisor(Server)

      assert pid != nil
      assert Process.alive?(pid)
    end

    test "MCP Server base process is running" do
      pid = Hermes.Server.Registry.whereis_server(Server)

      assert pid != nil
      assert Process.alive?(pid)
    end
  end
end

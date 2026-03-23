defmodule Agents.Sessions.Application.SessionsConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.SessionsConfig

  setup do
    original = Application.get_env(:agents, :sessions)

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:agents, :sessions)
      else
        Application.put_env(:agents, :sessions, original)
      end
    end)

    :ok
  end

  describe "image/0" do
    test "returns configured image name" do
      assert is_binary(SessionsConfig.image())
    end
  end

  describe "health_check_interval_ms/0" do
    test "returns configured interval" do
      assert is_integer(SessionsConfig.health_check_interval_ms())
      assert SessionsConfig.health_check_interval_ms() > 0
    end
  end

  describe "health_check_max_retries/0" do
    test "returns configured retries" do
      assert is_integer(SessionsConfig.health_check_max_retries())
      assert SessionsConfig.health_check_max_retries() > 0
    end
  end

  describe "question_timeout_ms/0" do
    test "returns configured timeout" do
      assert is_integer(SessionsConfig.question_timeout_ms())
      assert SessionsConfig.question_timeout_ms() > 0
    end
  end

  describe "container_env/0" do
    test "returns a map" do
      assert is_map(SessionsConfig.container_env())
    end
  end

  describe "default_warm_cache_limit/0" do
    test "returns 2 by default" do
      assert SessionsConfig.default_warm_cache_limit() == 2
    end
  end

  describe "available_images/0" do
    test "includes OpenCode Light image" do
      images = SessionsConfig.available_images()
      assert Enum.any?(images, &(&1.name == "perme8-opencode-light"))
    end

    test "includes all three standard images" do
      images = SessionsConfig.available_images()
      names = Enum.map(images, & &1.name)
      assert "perme8-opencode" in names
      assert "perme8-opencode-light" in names
      assert "perme8-pi" in names
    end

    test "returns list of 3 images" do
      assert length(SessionsConfig.available_images()) == 3
    end
  end

  describe "idle_suspend_timeout_ms/0" do
    test "returns configured idle suspension timeout" do
      assert is_integer(SessionsConfig.idle_suspend_timeout_ms())
      assert SessionsConfig.idle_suspend_timeout_ms() > 0
    end
  end

  describe "setup_phase_instruction/1" do
    test "returns configured setup instructions" do
      Application.put_env(:agents, :sessions,
        setup_phases: %{on_create: "prepare repo", on_resume: "restore context"}
      )

      assert SessionsConfig.setup_phase_instruction(:on_create) == "prepare repo"
      assert SessionsConfig.setup_phase_instruction(:on_resume) == "restore context"
    end

    test "returns nil when setup instruction is not configured" do
      Application.put_env(:agents, :sessions, [])
      assert SessionsConfig.setup_phase_instruction(:on_create) == nil
    end
  end
end

defmodule Agents.Sessions.Application.SessionsConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.SessionsConfig

  describe "image/0" do
    test "returns configured image name" do
      assert is_binary(SessionsConfig.image())
    end
  end

  describe "max_concurrent_tasks/0" do
    test "returns configured limit" do
      assert is_integer(SessionsConfig.max_concurrent_tasks())
      assert SessionsConfig.max_concurrent_tasks() >= 1
    end
  end

  describe "task_timeout_ms/0" do
    test "returns configured timeout" do
      assert is_integer(SessionsConfig.task_timeout_ms())
      assert SessionsConfig.task_timeout_ms() > 0
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

  describe "container_env/0" do
    test "returns a map" do
      assert is_map(SessionsConfig.container_env())
    end
  end
end

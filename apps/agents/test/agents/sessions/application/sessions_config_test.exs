defmodule Agents.Sessions.Application.SessionsConfigTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.SessionsConfig

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

  describe "queue_v2_enabled?/0" do
    test "returns false by default" do
      refute SessionsConfig.queue_v2_enabled?()
    end
  end

  describe "default_warm_cache_limit/0" do
    test "returns 2 by default" do
      assert SessionsConfig.default_warm_cache_limit() == 2
    end
  end
end

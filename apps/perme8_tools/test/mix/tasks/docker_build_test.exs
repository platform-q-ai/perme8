defmodule Mix.Tasks.Docker.BuildTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Mix.Tasks.Docker.Build

  describe "resolve_config/1" do
    test "defaults to opencode image when no argument given" do
      assert {:ok, config} = Build.resolve_config([])
      assert config.image_name == "opencode"
      assert config.image_path == "infra/opencode"
      assert config.tag == "perme8-opencode"
      assert config.no_cache == false
    end

    test "accepts opencode as explicit argument" do
      assert {:ok, config} = Build.resolve_config(["opencode"])
      assert config.image_name == "opencode"
      assert config.image_path == "infra/opencode"
    end

    test "accepts pi as argument" do
      assert {:ok, config} = Build.resolve_config(["pi"])
      assert config.image_name == "pi"
      assert config.image_path == "infra/pi"
      assert config.tag == "perme8-pi"
    end

    test "accepts opencode-light as argument" do
      assert {:ok, config} = Build.resolve_config(["opencode-light"])
      assert config.image_name == "opencode-light"
      assert config.image_path == "infra/opencode-light"
      assert config.tag == "perme8-opencode-light"
    end

    test "rejects unknown image names" do
      assert {:error, message} = Build.resolve_config(["unknown"])
      assert message =~ "Unknown image: unknown"
      assert message =~ "opencode"
      assert message =~ "pi"
      assert message =~ "opencode-light"
    end

    test "--tag overrides default tag" do
      assert {:ok, config} = Build.resolve_config(["pi", "--tag", "my-custom-tag"])
      assert config.tag == "my-custom-tag"
    end

    test "-t alias works for --tag" do
      assert {:ok, config} = Build.resolve_config(["opencode", "-t", "alias-tag"])
      assert config.tag == "alias-tag"
    end

    test "--no-cache flag is captured" do
      assert {:ok, config} = Build.resolve_config(["pi", "--no-cache"])
      assert config.no_cache == true
    end

    test "no-cache defaults to false" do
      assert {:ok, config} = Build.resolve_config(["pi"])
      assert config.no_cache == false
    end
  end

  describe "build_docker_args/3" do
    test "builds basic docker args without cache flag" do
      args = Build.build_docker_args("perme8-pi", false, "/path/to/context")
      assert args == ["build", "-t", "perme8-pi", "/path/to/context"]
    end

    test "includes --no-cache when requested" do
      args = Build.build_docker_args("perme8-pi", true, "/path/to/context")
      assert args == ["build", "-t", "perme8-pi", "--no-cache", "/path/to/context"]
    end
  end
end

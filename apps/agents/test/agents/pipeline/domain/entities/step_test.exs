defmodule Agents.Pipeline.Domain.Entities.StepTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Step

  describe "new/1" do
    test "creates a Step struct with all fields" do
      step = Step.new(%{name: "build", command: "mix compile"})

      assert %Step{} = step
      assert step.name == "build"
      assert step.command == "mix compile"
    end

    test "sets sensible defaults" do
      step = Step.new(%{name: "test"})

      assert step.type == "command"
      assert step.command == nil
      assert step.commands == []
      assert step.image == nil
      assert step.env == %{}
      assert step.when_condition == nil
    end

    test "accepts all fields" do
      step =
        Step.new(%{
          name: "deploy",
          type: "provision_container",
          command: "echo hello",
          commands: ["echo one", "echo two"],
          image: "opencode",
          env: %{"FOO" => "bar"},
          when_condition: "changes_in_app"
        })

      assert step.name == "deploy"
      assert step.type == "provision_container"
      assert step.command == "echo hello"
      assert step.commands == ["echo one", "echo two"]
      assert step.image == "opencode"
      assert step.env == %{"FOO" => "bar"}
      assert step.when_condition == "changes_in_app"
    end
  end

  describe "command_or_commands/1" do
    test "returns single command as a list when only command is set" do
      step = Step.new(%{name: "build", command: "mix compile"})

      assert Step.command_or_commands(step) == ["mix compile"]
    end

    test "returns commands list when commands is set" do
      step = Step.new(%{name: "build", commands: ["mix deps.get", "mix compile"]})

      assert Step.command_or_commands(step) == ["mix deps.get", "mix compile"]
    end

    test "returns empty list when neither is set" do
      step = Step.new(%{name: "placeholder"})

      assert Step.command_or_commands(step) == []
    end

    test "prefers commands list over single command when both set" do
      step = Step.new(%{name: "build", command: "mix compile", commands: ["mix deps.get"]})

      assert Step.command_or_commands(step) == ["mix deps.get"]
    end
  end

  describe "provision_step?/1" do
    test "returns true for provision_container type" do
      step = Step.new(%{name: "provision", type: "provision_container"})

      assert Step.provision_step?(step) == true
    end

    test "returns true for mark_container_ready type" do
      step = Step.new(%{name: "ready", type: "mark_container_ready"})

      assert Step.provision_step?(step) == true
    end

    test "returns false for command type" do
      step = Step.new(%{name: "build", type: "command"})

      assert Step.provision_step?(step) == false
    end

    test "returns false for default type" do
      step = Step.new(%{name: "build"})

      assert Step.provision_step?(step) == false
    end
  end
end

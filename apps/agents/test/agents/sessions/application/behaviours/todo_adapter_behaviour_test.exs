defmodule Agents.Sessions.Application.Behaviours.TodoAdapterBehaviourTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.Behaviours.TodoAdapterBehaviour

  describe "callbacks" do
    @expected_callbacks [
      parse_event: 1,
      get_todos: 1,
      store_todos: 2,
      clear_todos: 1
    ]

    test "defines all todo adapter callbacks" do
      callbacks = TodoAdapterBehaviour.behaviour_info(:callbacks)

      for {name, arity} <- @expected_callbacks do
        assert {name, arity} in callbacks,
               "Expected callback #{name}/#{arity} to be defined, got: #{inspect(callbacks)}"
      end

      assert length(callbacks) == 4,
             "Expected exactly 4 callbacks, got #{length(callbacks)}: #{inspect(callbacks)}"
    end
  end

  describe "mox integration" do
    test "can define a mox mock against the behaviour" do
      mock_module = Mox.defmock(Agents.Mocks.TodoAdapterInlineMock, for: TodoAdapterBehaviour)

      assert mock_module == Agents.Mocks.TodoAdapterInlineMock
      assert function_exported?(mock_module, :parse_event, 1)
      assert function_exported?(mock_module, :get_todos, 1)
      assert function_exported?(mock_module, :store_todos, 2)
      assert function_exported?(mock_module, :clear_todos, 1)
    end
  end
end

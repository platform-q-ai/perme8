defmodule EntityRelationshipManager.Domain.Policies.TraversalPolicyTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Policies.TraversalPolicy

  describe "validate_depth/1" do
    test "accepts valid depths from 1 to 10" do
      for depth <- 1..10 do
        assert :ok = TraversalPolicy.validate_depth(depth)
      end
    end

    test "rejects depth of 0" do
      assert {:error, reason} = TraversalPolicy.validate_depth(0)
      assert is_binary(reason)
    end

    test "rejects negative depth" do
      assert {:error, reason} = TraversalPolicy.validate_depth(-1)
      assert is_binary(reason)
    end

    test "rejects depth greater than 10" do
      assert {:error, reason} = TraversalPolicy.validate_depth(11)
      assert is_binary(reason)
    end

    test "rejects non-integer depth" do
      assert {:error, reason} = TraversalPolicy.validate_depth(1.5)
      assert is_binary(reason)
    end
  end

  describe "validate_direction/1" do
    test "accepts 'in' direction" do
      assert :ok = TraversalPolicy.validate_direction("in")
    end

    test "accepts 'out' direction" do
      assert :ok = TraversalPolicy.validate_direction("out")
    end

    test "accepts 'both' direction" do
      assert :ok = TraversalPolicy.validate_direction("both")
    end

    test "rejects invalid direction" do
      assert {:error, reason} = TraversalPolicy.validate_direction("left")
      assert is_binary(reason)
    end

    test "rejects nil direction" do
      assert {:error, reason} = TraversalPolicy.validate_direction(nil)
      assert is_binary(reason)
    end
  end

  describe "validate_limit/1" do
    test "accepts valid limits from 1 to 500" do
      assert :ok = TraversalPolicy.validate_limit(1)
      assert :ok = TraversalPolicy.validate_limit(250)
      assert :ok = TraversalPolicy.validate_limit(500)
    end

    test "rejects limit of 0" do
      assert {:error, reason} = TraversalPolicy.validate_limit(0)
      assert is_binary(reason)
    end

    test "rejects negative limit" do
      assert {:error, reason} = TraversalPolicy.validate_limit(-1)
      assert is_binary(reason)
    end

    test "rejects limit greater than 500" do
      assert {:error, reason} = TraversalPolicy.validate_limit(501)
      assert is_binary(reason)
    end

    test "rejects non-integer limit" do
      assert {:error, reason} = TraversalPolicy.validate_limit(10.5)
      assert is_binary(reason)
    end
  end

  describe "validate_offset/1" do
    test "accepts zero offset" do
      assert :ok = TraversalPolicy.validate_offset(0)
    end

    test "accepts positive offset" do
      assert :ok = TraversalPolicy.validate_offset(100)
    end

    test "rejects negative offset" do
      assert {:error, reason} = TraversalPolicy.validate_offset(-1)
      assert is_binary(reason)
    end

    test "rejects non-integer offset" do
      assert {:error, reason} = TraversalPolicy.validate_offset(1.5)
      assert is_binary(reason)
    end
  end

  describe "default_depth/0" do
    test "returns 1" do
      assert TraversalPolicy.default_depth() == 1
    end
  end

  describe "max_depth/0" do
    test "returns 10" do
      assert TraversalPolicy.max_depth() == 10
    end
  end
end

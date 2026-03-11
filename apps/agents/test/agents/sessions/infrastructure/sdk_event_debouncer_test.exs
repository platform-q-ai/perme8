defmodule Agents.Sessions.Infrastructure.SdkEventDebouncerTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.SdkEventDebouncer

  describe "new/0" do
    test "creates empty debouncer state" do
      debouncer = SdkEventDebouncer.new()
      assert debouncer == %{}
    end
  end

  describe "should_emit?/2" do
    test "returns true for first emission of any type" do
      debouncer = SdkEventDebouncer.new()
      assert SdkEventDebouncer.should_emit?(debouncer, :message_part_updated)
    end

    test "returns false if last emission was less than interval ago" do
      debouncer = SdkEventDebouncer.new()
      {true, debouncer} = SdkEventDebouncer.check_and_record(debouncer, :message_part_updated)

      assert SdkEventDebouncer.should_emit?(debouncer, :message_part_updated) == false
    end

    test "returns true for non-debounced event types" do
      debouncer = SdkEventDebouncer.new()
      {true, debouncer} = SdkEventDebouncer.check_and_record(debouncer, :state_changed)

      assert SdkEventDebouncer.should_emit?(debouncer, :state_changed) == true
    end

    test "returns true after interval has passed" do
      now = System.monotonic_time(:millisecond)
      past = now - 1_000
      debouncer = %{message_part_updated: past}

      assert SdkEventDebouncer.should_emit?(debouncer, :message_part_updated, interval: 500)
    end
  end

  describe "check_and_record/2" do
    test "returns {true, updated_debouncer} on first call" do
      debouncer = SdkEventDebouncer.new()

      assert {true, updated} =
               SdkEventDebouncer.check_and_record(debouncer, :message_part_updated)

      assert Map.has_key?(updated, :message_part_updated)
    end

    test "returns {false, debouncer} when throttled" do
      debouncer = SdkEventDebouncer.new()
      {true, debouncer} = SdkEventDebouncer.check_and_record(debouncer, :message_part_updated)

      assert {false, ^debouncer} =
               SdkEventDebouncer.check_and_record(debouncer, :message_part_updated)
    end

    test "always returns {true, _} for non-debounced event types" do
      debouncer = SdkEventDebouncer.new()
      {true, debouncer} = SdkEventDebouncer.check_and_record(debouncer, :state_changed)
      {true, _} = SdkEventDebouncer.check_and_record(debouncer, :state_changed)
    end
  end

  describe "debounced_type?/1" do
    test "message_part_updated is debounced" do
      assert SdkEventDebouncer.debounced_type?(:message_part_updated)
    end

    test "state_changed is not debounced" do
      refute SdkEventDebouncer.debounced_type?(:state_changed)
    end

    test "error_occurred is not debounced" do
      refute SdkEventDebouncer.debounced_type?(:error_occurred)
    end

    test "permission_requested is not debounced" do
      refute SdkEventDebouncer.debounced_type?(:permission_requested)
    end
  end
end

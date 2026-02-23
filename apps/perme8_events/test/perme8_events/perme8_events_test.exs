defmodule Perme8.EventsTest do
  use ExUnit.Case, async: false

  @pubsub Application.compile_env(:perme8_events, :pubsub, Perme8.Events.PubSub)

  describe "subscribe/1" do
    test "subscribes the calling process to a topic" do
      topic = "events:test:#{System.unique_integer()}"
      :ok = Perme8.Events.subscribe(topic)

      # Broadcast on the topic and verify we receive the message
      Phoenix.PubSub.broadcast(@pubsub, topic, :test_message)
      assert_receive :test_message
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribes the calling process from a topic" do
      topic = "events:test:#{System.unique_integer()}"
      :ok = Perme8.Events.subscribe(topic)
      :ok = Perme8.Events.unsubscribe(topic)

      # Broadcast on the topic and verify we do NOT receive the message
      Phoenix.PubSub.broadcast(@pubsub, topic, :test_message)
      refute_receive :test_message, 100
    end
  end
end

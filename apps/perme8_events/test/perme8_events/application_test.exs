defmodule Perme8Events.ApplicationTest do
  use ExUnit.Case

  describe "PubSub supervision" do
    test "Perme8.Events.PubSub process is running" do
      # The application is started by the test runner, so PubSub should be alive
      pubsub = Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub)
      assert Process.whereis(pubsub) != nil
    end
  end
end

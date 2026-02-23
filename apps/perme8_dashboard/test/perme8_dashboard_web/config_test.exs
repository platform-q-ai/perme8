defmodule Perme8DashboardWeb.ConfigTest do
  use ExUnit.Case, async: true

  describe "endpoint config" do
    test "endpoint config is set" do
      config = Application.get_env(:perme8_dashboard, Perme8DashboardWeb.Endpoint)
      assert config != nil
      assert Keyword.get(config, :url) == [host: "localhost"]
    end

    test "PubSub config uses Perme8.Events.PubSub" do
      config = Application.get_env(:perme8_dashboard, Perme8DashboardWeb.Endpoint)
      assert Keyword.get(config, :pubsub_server) == Perme8.Events.PubSub
    end

    test "render_errors is configured" do
      config = Application.get_env(:perme8_dashboard, Perme8DashboardWeb.Endpoint)
      render_errors = Keyword.get(config, :render_errors)
      assert render_errors[:formats] == [html: Perme8DashboardWeb.ErrorHTML]
      assert render_errors[:layout] == false
    end

    test "live_view signing salt is configured" do
      config = Application.get_env(:perme8_dashboard, Perme8DashboardWeb.Endpoint)
      assert Keyword.get(config, :live_view) == [signing_salt: "perme8_dashboard_salt"]
    end
  end
end

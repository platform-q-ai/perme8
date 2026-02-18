defmodule Agents.Application.GatewayConfigJargaTest do
  use ExUnit.Case, async: false

  alias Agents.Application.GatewayConfig

  describe "jarga_gateway/0" do
    test "returns default JargaGateway module when no override configured" do
      Application.delete_env(:agents, :jarga_gateway)

      assert GatewayConfig.jarga_gateway() ==
               Agents.Infrastructure.Gateways.JargaGateway
    end

    test "returns configured module when override is set" do
      Application.put_env(:agents, :jarga_gateway, MyApp.FakeJargaGateway)

      on_exit(fn -> Application.delete_env(:agents, :jarga_gateway) end)

      assert GatewayConfig.jarga_gateway() == MyApp.FakeJargaGateway
    end
  end
end

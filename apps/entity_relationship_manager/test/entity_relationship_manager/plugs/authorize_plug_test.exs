defmodule EntityRelationshipManager.Plugs.AuthorizePlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias EntityRelationshipManager.Plugs.AuthorizePlug

  defp build_conn(role) do
    Plug.Test.conn(:get, "/")
    |> assign(:member, %{role: role})
  end

  describe "call/2 with authorized role" do
    test "owner can perform any action" do
      conn =
        build_conn(:owner)
        |> AuthorizePlug.call(action: :write_schema)

      refute conn.halted
    end

    test "admin can perform any action" do
      conn =
        build_conn(:admin)
        |> AuthorizePlug.call(action: :create_entity)

      refute conn.halted
    end

    test "member can create entities" do
      conn =
        build_conn(:member)
        |> AuthorizePlug.call(action: :create_entity)

      refute conn.halted
    end

    test "guest can read entities" do
      conn =
        build_conn(:guest)
        |> AuthorizePlug.call(action: :read_entity)

      refute conn.halted
    end
  end

  describe "call/2 with unauthorized role" do
    test "guest cannot create entities" do
      conn =
        build_conn(:guest)
        |> AuthorizePlug.call(action: :create_entity)

      assert conn.halted
      assert conn.status == 403
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "forbidden"
      assert body["message"] =~ "permission"
    end

    test "member cannot write schema" do
      conn =
        build_conn(:member)
        |> AuthorizePlug.call(action: :write_schema)

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 without member assign" do
    test "returns 403 when member is nil" do
      conn =
        Plug.Test.conn(:get, "/")
        |> AuthorizePlug.call(action: :read_entity)

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "init/1" do
    test "passes opts through" do
      opts = [action: :read_entity]
      assert AuthorizePlug.init(opts) == opts
    end
  end
end

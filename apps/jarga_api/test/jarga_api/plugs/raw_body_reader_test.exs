defmodule JargaApi.Plugs.RawBodyReaderTest do
  use ExUnit.Case, async: true

  alias JargaApi.Plugs.RawBodyReader

  describe "read_body/2" do
    test "reads body and stores raw bytes in conn private" do
      body = ~s({"event":"test.created","data":{"id":"123"}})

      # Simulate Plug.Parsers calling our custom body reader
      # The read_body/2 function receives conn and opts, returns {status, body, conn}
      conn = Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, :post, "/", body)
      {status, read_body, conn} = RawBodyReader.read_body(conn, [])

      assert status == :ok
      assert read_body == body
      assert conn.private[:raw_body] == body
    end

    test "handles empty body" do
      conn = Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, :post, "/", "")
      {status, read_body, conn} = RawBodyReader.read_body(conn, [])

      assert status == :ok
      assert read_body == ""
      assert conn.private[:raw_body] == ""
    end
  end
end

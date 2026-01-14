defmodule Jarga.ChatTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for the Chat context public API.

  This context handles chat session and message management,
  separate from the Agents context.
  """

  describe "module compilation" do
    test "Chat context module exists and compiles" do
      # This test ensures the Chat context module is properly defined
      assert Code.ensure_loaded?(Jarga.Chat)
      assert {:module, Jarga.Chat} == Code.ensure_loaded(Jarga.Chat)
    end

    test "Chat context has module documentation" do
      # Verify the module has proper documentation
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Jarga.Chat)
      assert moduledoc =~ "Chat context"
    end
  end
end

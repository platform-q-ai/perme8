defmodule Jarga.Documents.Notes.Domain.ContentHashTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Notes.Domain.ContentHash

  describe "compute/1" do
    test "returns a 64-character hex string for non-empty content" do
      hash = ContentHash.compute("Hello world")
      assert String.length(hash) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hash)
    end

    test "returns consistent hash for same content" do
      hash1 = ContentHash.compute("same content")
      hash2 = ContentHash.compute("same content")
      assert hash1 == hash2
    end

    test "returns different hashes for different content" do
      hash1 = ContentHash.compute("content a")
      hash2 = ContentHash.compute("content b")
      refute hash1 == hash2
    end

    test "nil content produces same hash as empty string" do
      assert ContentHash.compute(nil) == ContentHash.compute("")
    end

    test "empty string produces a valid hash" do
      hash = ContentHash.compute("")
      assert String.length(hash) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hash)
    end

    test "hash matches known SHA-256 value" do
      # SHA-256 of empty string is well-known
      expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      assert ContentHash.compute("") == expected
    end

    test "handles unicode content" do
      hash = ContentHash.compute("Hello ")
      assert String.length(hash) == 64
    end
  end
end

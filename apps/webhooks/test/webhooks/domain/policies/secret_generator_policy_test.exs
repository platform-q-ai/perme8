defmodule Webhooks.Domain.Policies.SecretGeneratorPolicyTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Policies.SecretGeneratorPolicy

  describe "generate/0" do
    test "returns a string of at least 32 characters" do
      secret = SecretGeneratorPolicy.generate()

      assert is_binary(secret)
      assert String.length(secret) >= 32
    end

    test "returns unique values on repeated calls" do
      secret1 = SecretGeneratorPolicy.generate()
      secret2 = SecretGeneratorPolicy.generate()
      secret3 = SecretGeneratorPolicy.generate()

      assert secret1 != secret2
      assert secret2 != secret3
      assert secret1 != secret3
    end

    test "returns URL-safe characters" do
      secret = SecretGeneratorPolicy.generate()

      # Base.url_encode64 uses A-Z, a-z, 0-9, -, _
      assert String.match?(secret, ~r/^[A-Za-z0-9_-]+$/)
    end
  end

  describe "sufficient_length?/1" do
    test "returns true for strings >= 32 characters" do
      long_secret = String.duplicate("a", 32)
      assert SecretGeneratorPolicy.sufficient_length?(long_secret) == true
    end

    test "returns true for strings longer than 32 characters" do
      long_secret = String.duplicate("a", 64)
      assert SecretGeneratorPolicy.sufficient_length?(long_secret) == true
    end

    test "returns false for strings < 32 characters" do
      short_secret = String.duplicate("a", 31)
      assert SecretGeneratorPolicy.sufficient_length?(short_secret) == false
    end

    test "returns false for empty string" do
      assert SecretGeneratorPolicy.sufficient_length?("") == false
    end
  end
end

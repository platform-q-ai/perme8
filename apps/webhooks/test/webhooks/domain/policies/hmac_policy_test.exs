defmodule Webhooks.Domain.Policies.HmacPolicyTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Policies.HmacPolicy

  @secret "whsec_test_secret_key_for_hmac_testing"
  @payload ~s({"event":"project.created","data":{"id":"proj-1"}})

  describe "compute_signature/2" do
    test "returns HMAC-SHA256 hex digest" do
      signature = HmacPolicy.compute_signature(@secret, @payload)

      # Should be a 64-char lowercase hex string (SHA256 = 32 bytes = 64 hex chars)
      assert is_binary(signature)
      assert String.length(signature) == 64
      assert String.match?(signature, ~r/^[a-f0-9]{64}$/)
    end

    test "returns consistent signature for same inputs" do
      sig1 = HmacPolicy.compute_signature(@secret, @payload)
      sig2 = HmacPolicy.compute_signature(@secret, @payload)

      assert sig1 == sig2
    end

    test "returns different signatures for different secrets" do
      sig1 = HmacPolicy.compute_signature("secret-1", @payload)
      sig2 = HmacPolicy.compute_signature("secret-2", @payload)

      refute sig1 == sig2
    end

    test "returns different signatures for different payloads" do
      sig1 = HmacPolicy.compute_signature(@secret, "payload-1")
      sig2 = HmacPolicy.compute_signature(@secret, "payload-2")

      refute sig1 == sig2
    end

    test "works with binary payload (raw JSON string)" do
      raw_json = ~s({"key":"value","nested":{"num":42}})
      signature = HmacPolicy.compute_signature(@secret, raw_json)

      assert is_binary(signature)
      assert String.length(signature) == 64
    end
  end

  describe "valid_signature?/3" do
    test "returns true when signature matches" do
      signature = HmacPolicy.compute_signature(@secret, @payload)

      assert HmacPolicy.valid_signature?(@secret, @payload, signature) == true
    end

    test "returns false when signature does not match" do
      assert HmacPolicy.valid_signature?(@secret, @payload, "invalid_signature") == false
    end

    test "returns false for nil signature" do
      assert HmacPolicy.valid_signature?(@secret, @payload, nil) == false
    end

    test "returns false for empty string signature" do
      assert HmacPolicy.valid_signature?(@secret, @payload, "") == false
    end

    test "returns false for tampered payload" do
      signature = HmacPolicy.compute_signature(@secret, @payload)
      tampered = @payload <> "extra"

      assert HmacPolicy.valid_signature?(@secret, tampered, signature) == false
    end
  end
end

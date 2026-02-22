defmodule Jarga.Webhooks.Domain.Policies.SignaturePolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Policies.SignaturePolicy

  @test_secret "whsec_test_secret_key"
  @test_payload ~s({"event":"test"})

  describe "sign/2" do
    test "generates HMAC-SHA256 hex digest" do
      signature = SignaturePolicy.sign(@test_payload, @test_secret)

      assert is_binary(signature)
      # SHA-256 hex digest is 64 chars
      assert String.length(signature) == 64
      # Only hex chars
      assert Regex.match?(~r/^[a-f0-9]+$/, signature)
    end

    test "produces consistent results for same input" do
      sig1 = SignaturePolicy.sign(@test_payload, @test_secret)
      sig2 = SignaturePolicy.sign(@test_payload, @test_secret)

      assert sig1 == sig2
    end

    test "produces different results for different secrets" do
      sig1 = SignaturePolicy.sign(@test_payload, "secret1")
      sig2 = SignaturePolicy.sign(@test_payload, "secret2")

      assert sig1 != sig2
    end

    test "produces different results for different payloads" do
      sig1 = SignaturePolicy.sign("payload1", @test_secret)
      sig2 = SignaturePolicy.sign("payload2", @test_secret)

      assert sig1 != sig2
    end
  end

  describe "verify/3" do
    test "returns true when computed HMAC matches provided signature" do
      signature = SignaturePolicy.sign(@test_payload, @test_secret)
      assert SignaturePolicy.verify(@test_payload, @test_secret, signature) == true
    end

    test "returns false for mismatched signature" do
      assert SignaturePolicy.verify(@test_payload, @test_secret, "invalid_signature") == false
    end

    test "returns false for nil signature" do
      assert SignaturePolicy.verify(@test_payload, @test_secret, nil) == false
    end

    test "returns false for empty signature" do
      assert SignaturePolicy.verify(@test_payload, @test_secret, "") == false
    end
  end

  describe "build_signature_header/2" do
    test "returns sha256=<hex> format string" do
      header = SignaturePolicy.build_signature_header(@test_payload, @test_secret)

      assert String.starts_with?(header, "sha256=")
      hex_part = String.replace_prefix(header, "sha256=", "")
      assert String.length(hex_part) == 64
    end
  end

  describe "parse_signature_header/1" do
    test "extracts hex digest from sha256=<hex> format" do
      signature = SignaturePolicy.sign(@test_payload, @test_secret)
      header = "sha256=#{signature}"

      assert {:ok, ^signature} = SignaturePolicy.parse_signature_header(header)
    end

    test "returns error for invalid format" do
      assert {:error, :invalid_format} = SignaturePolicy.parse_signature_header("invalid")
    end

    test "returns error for nil input" do
      assert {:error, :invalid_format} = SignaturePolicy.parse_signature_header(nil)
    end

    test "returns error for empty string" do
      assert {:error, :invalid_format} = SignaturePolicy.parse_signature_header("")
    end

    test "returns error for wrong prefix" do
      assert {:error, :invalid_format} = SignaturePolicy.parse_signature_header("md5=abc123")
    end
  end
end

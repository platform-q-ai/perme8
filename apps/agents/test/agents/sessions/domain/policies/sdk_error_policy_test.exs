defmodule Agents.Sessions.Domain.Policies.SdkErrorPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.SdkErrorPolicy

  describe "classify/1" do
    test "classifies auth errors as terminal" do
      assert SdkErrorPolicy.classify("auth") == {:terminal, :auth}
    end

    test "classifies abort errors as terminal" do
      assert SdkErrorPolicy.classify("abort") == {:terminal, :abort}
    end

    test "classifies api errors as recoverable" do
      assert SdkErrorPolicy.classify("api") == {:recoverable, :api}
    end

    test "classifies output_length errors as recoverable" do
      assert SdkErrorPolicy.classify("output_length") == {:recoverable, :output_length}
    end

    test "classifies rate_limit errors as recoverable" do
      assert SdkErrorPolicy.classify("rate_limit") == {:recoverable, :rate_limit}
    end

    test "classifies nil as terminal unknown" do
      assert SdkErrorPolicy.classify(nil) == {:terminal, :unknown}
    end

    test "classifies unrecognized categories as terminal unknown (fail-safe)" do
      assert SdkErrorPolicy.classify("something_weird") == {:terminal, :unknown}
      assert SdkErrorPolicy.classify("") == {:terminal, :unknown}
    end
  end

  describe "terminal?/1" do
    test "returns true for terminal categories" do
      assert SdkErrorPolicy.terminal?("auth")
      assert SdkErrorPolicy.terminal?("abort")
      assert SdkErrorPolicy.terminal?(nil)
      assert SdkErrorPolicy.terminal?("unknown_thing")
    end

    test "returns false for recoverable categories" do
      refute SdkErrorPolicy.terminal?("api")
      refute SdkErrorPolicy.terminal?("output_length")
      refute SdkErrorPolicy.terminal?("rate_limit")
    end
  end

  describe "recoverable?/1" do
    test "returns true for recoverable categories" do
      assert SdkErrorPolicy.recoverable?("api")
      assert SdkErrorPolicy.recoverable?("output_length")
      assert SdkErrorPolicy.recoverable?("rate_limit")
    end

    test "returns false for terminal categories" do
      refute SdkErrorPolicy.recoverable?("auth")
      refute SdkErrorPolicy.recoverable?("abort")
      refute SdkErrorPolicy.recoverable?(nil)
    end
  end
end

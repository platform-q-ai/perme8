defmodule ExoDashboard.Features.Domain.Policies.AdapterClassifierTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Domain.Policies.AdapterClassifier

  describe "classify/1" do
    test "extracts :browser adapter from filename" do
      assert AdapterClassifier.classify("login.browser.feature") == :browser
    end

    test "extracts :http adapter from filename" do
      assert AdapterClassifier.classify("api_users.http.feature") == :http
    end

    test "extracts :security adapter from filename" do
      assert AdapterClassifier.classify("auth.security.feature") == :security
    end

    test "extracts :cli adapter from filename" do
      assert AdapterClassifier.classify("deploy.cli.feature") == :cli
    end

    test "extracts :graph adapter from filename" do
      assert AdapterClassifier.classify("query.graph.feature") == :graph
    end

    test "returns :unknown for files without adapter suffix" do
      assert AdapterClassifier.classify("plain.feature") == :unknown
    end

    test "returns :unknown for files with unrecognized adapter suffix" do
      assert AdapterClassifier.classify("test.foobar.feature") == :unknown
    end

    test "handles full paths, extracts adapter from filename only" do
      path = "apps/jarga_web/test/features/login.browser.feature"
      assert AdapterClassifier.classify(path) == :browser
    end

    test "handles deeply nested paths" do
      path = "apps/identity/test/features/auth/sessions/login.http.feature"
      assert AdapterClassifier.classify(path) == :http
    end
  end

  describe "app_from_path/1" do
    test "extracts app name from standard umbrella path" do
      path = "apps/jarga_web/test/features/login.browser.feature"
      assert AdapterClassifier.app_from_path(path) == "jarga_web"
    end

    test "extracts app name from deeply nested path" do
      path = "apps/identity/test/features/auth/sessions/login.http.feature"
      assert AdapterClassifier.app_from_path(path) == "identity"
    end

    test "returns nil for paths not matching umbrella structure" do
      assert AdapterClassifier.app_from_path("some/random/path.feature") == nil
    end
  end
end

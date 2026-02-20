defmodule ExoDashboard.Features.Application.UseCases.DiscoverFeaturesTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Application.UseCases.DiscoverFeatures
  alias ExoDashboard.Features.Domain.Entities.Feature
  alias ExoDashboard.Features.Domain.Entities.Scenario

  # Mock scanner that returns a fixed list of paths
  defmodule MockScanner do
    def scan(_opts \\ []) do
      [
        "apps/jarga_web/test/features/login.browser.feature",
        "apps/jarga_web/test/features/api.http.feature",
        "apps/identity/test/features/auth.security.feature"
      ]
    end
  end

  # Mock parser that returns a fixed Feature struct for any path
  defmodule MockParser do
    def parse(path) do
      name =
        path
        |> Path.basename()
        |> String.replace(~r/\.\w+\.feature$/, "")
        |> String.replace(".feature", "")
        |> String.capitalize()

      scenario = Scenario.new(id: "s-1", name: "Test scenario for #{name}")

      {:ok,
       Feature.new(
         uri: path,
         name: name,
         children: [scenario]
       )}
    end
  end

  describe "execute/1" do
    test "scans disk and parses all features, returns grouped catalog" do
      result = DiscoverFeatures.execute(scanner: MockScanner, parser: MockParser)

      assert {:ok, catalog} = result
      assert is_map(catalog.apps)
      assert is_map(catalog.by_adapter)
    end

    test "groups features by app name" do
      {:ok, catalog} = DiscoverFeatures.execute(scanner: MockScanner, parser: MockParser)

      assert Map.has_key?(catalog.apps, "jarga_web")
      assert Map.has_key?(catalog.apps, "identity")
      assert length(catalog.apps["jarga_web"]) == 2
      assert length(catalog.apps["identity"]) == 1
    end

    test "groups features by adapter type" do
      {:ok, catalog} = DiscoverFeatures.execute(scanner: MockScanner, parser: MockParser)

      assert Map.has_key?(catalog.by_adapter, :browser)
      assert Map.has_key?(catalog.by_adapter, :http)
      assert Map.has_key?(catalog.by_adapter, :security)
      assert length(catalog.by_adapter[:browser]) == 1
      assert length(catalog.by_adapter[:http]) == 1
      assert length(catalog.by_adapter[:security]) == 1
    end

    test "tags each feature with app and adapter" do
      {:ok, catalog} = DiscoverFeatures.execute(scanner: MockScanner, parser: MockParser)

      browser_features = catalog.by_adapter[:browser]
      assert length(browser_features) == 1
      feature = hd(browser_features)
      assert feature.adapter == :browser
      assert feature.app == "jarga_web"
    end

    test "handles empty scan results gracefully" do
      defmodule EmptyScanner do
        def scan(_opts \\ []), do: []
      end

      {:ok, catalog} = DiscoverFeatures.execute(scanner: EmptyScanner, parser: MockParser)
      assert catalog.apps == %{}
      assert catalog.by_adapter == %{}
    end
  end
end

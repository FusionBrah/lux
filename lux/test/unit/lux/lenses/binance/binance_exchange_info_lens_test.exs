defmodule Lux.Lenses.Binance.BinanceExchangeInfoLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.BinanceExchangeInfoLens

  describe "schema validation" do
    test "validates input schema" do
      lens = BinanceExchangeInfoLens.view()

      assert lens.schema.type == :object
      assert lens.schema.required == []
      assert Map.has_key?(lens.schema.properties, :symbol)
      assert Map.has_key?(lens.schema.properties, :symbols)
    end

    test "lens has correct metadata" do
      lens = BinanceExchangeInfoLens.view()

      assert lens.name == "Binance Exchange Info"
      assert String.contains?(lens.description, "exchange information")
      assert lens.method == :get
    end

    test "lens uses no authentication" do
      lens = BinanceExchangeInfoLens.view()

      assert lens.auth.type == :none
    end
  end

  describe "after_focus/1" do
    test "transforms exchange info response" do
      response = %{
        "timezone" => "UTC",
        "serverTime" => 1234567890123,
        "rateLimits" => [
          %{"rateLimitType" => "REQUEST_WEIGHT", "interval" => "MINUTE", "limit" => 1200}
        ],
        "symbols" => [
          %{
            "symbol" => "BTCUSDT",
            "status" => "TRADING",
            "baseAsset" => "BTC",
            "quoteAsset" => "USDT",
            "baseAssetPrecision" => 8,
            "quoteAssetPrecision" => 8,
            "orderTypes" => ["LIMIT", "MARKET"],
            "filters" => []
          }
        ]
      }

      assert {:ok, result} = BinanceExchangeInfoLens.after_focus(response)
      assert result.timezone == "UTC"
      assert result.server_time == 1234567890123
      assert length(result.symbols) == 1

      symbol = Enum.at(result.symbols, 0)
      assert symbol.symbol == "BTCUSDT"
      assert symbol.status == "TRADING"
      assert symbol.base_asset == "BTC"
      assert symbol.quote_asset == "USDT"
    end

    test "handles API error response" do
      response = %{
        "code" => -1121,
        "msg" => "Invalid symbol."
      }

      assert {:error, message} = BinanceExchangeInfoLens.after_focus(response)
      assert String.contains?(message, "-1121")
      assert String.contains?(message, "Invalid symbol")
    end
  end
end

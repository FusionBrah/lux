defmodule Lux.Lenses.Binance.BinanceTickerPriceLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.BinanceTickerPriceLens

  describe "schema validation" do
    test "validates input schema" do
      lens = BinanceTickerPriceLens.view()

      assert lens.schema.type == :object
      assert lens.schema.required == []
      assert Map.has_key?(lens.schema.properties, :symbol)
    end

    test "lens has correct metadata" do
      lens = BinanceTickerPriceLens.view()

      assert lens.name == "Binance Ticker Price"
      assert lens.description == "Fetches current ticker prices from Binance exchange"
      assert lens.method == :get
    end

    test "lens uses no authentication" do
      lens = BinanceTickerPriceLens.view()

      assert lens.auth.type == :none
    end
  end

  describe "after_focus/1" do
    test "transforms single symbol response" do
      response = %{
        "symbol" => "BTCUSDT",
        "price" => "42000.00000000"
      }

      assert {:ok, result} = BinanceTickerPriceLens.after_focus(response)
      assert result.symbol == "BTCUSDT"
      assert result.price == "42000.00000000"
    end

    test "transforms multiple symbols response" do
      response = [
        %{"symbol" => "BTCUSDT", "price" => "42000.00"},
        %{"symbol" => "ETHUSDT", "price" => "2800.00"}
      ]

      assert {:ok, result} = BinanceTickerPriceLens.after_focus(response)
      assert length(result.prices) == 2
      assert Enum.at(result.prices, 0).symbol == "BTCUSDT"
      assert Enum.at(result.prices, 1).symbol == "ETHUSDT"
    end

    test "handles API error response" do
      response = %{
        "code" => -1121,
        "msg" => "Invalid symbol."
      }

      assert {:error, message} = BinanceTickerPriceLens.after_focus(response)
      assert String.contains?(message, "-1121")
      assert String.contains?(message, "Invalid symbol")
    end
  end
end

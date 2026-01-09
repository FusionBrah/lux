defmodule Lux.Prisms.Binance.Spot.BinanceSpotOrderPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Spot.BinanceSpotOrderPrism

  describe "schema validation" do
    test "validates input schema" do
      prism = BinanceSpotOrderPrism.view()

      assert prism.input_schema.type == :object
      assert "symbol" in prism.input_schema.required
      assert "side" in prism.input_schema.required
      assert "type" in prism.input_schema.required

      # Check properties
      assert Map.has_key?(prism.input_schema.properties, :symbol)
      assert Map.has_key?(prism.input_schema.properties, :side)
      assert Map.has_key?(prism.input_schema.properties, :type)
      assert Map.has_key?(prism.input_schema.properties, :quantity)
      assert Map.has_key?(prism.input_schema.properties, :price)
      assert Map.has_key?(prism.input_schema.properties, :time_in_force)

      # Check enums
      side_prop = prism.input_schema.properties.side
      assert "BUY" in side_prop.enum
      assert "SELL" in side_prop.enum

      type_prop = prism.input_schema.properties.type
      assert "LIMIT" in type_prop.enum
      assert "MARKET" in type_prop.enum
    end

    test "validates output schema" do
      prism = BinanceSpotOrderPrism.view()

      assert prism.output_schema.type == :object
      assert "status" in prism.output_schema.required
      assert "order" in prism.output_schema.required
    end

    test "prism has correct metadata" do
      prism = BinanceSpotOrderPrism.view()

      assert prism.name == "Binance Spot Order"
      assert prism.description == "Places spot orders on Binance exchange"
    end
  end

  describe "handler/2 error cases" do
    test "returns error when API key is not configured" do
      Application.put_env(:lux, :accounts, [])

      result = BinanceSpotOrderPrism.handler(%{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "MARKET",
        quantity: 0.001
      }, %{})

      assert {:error, "Binance API key is not configured"} = result
    end
  end
end

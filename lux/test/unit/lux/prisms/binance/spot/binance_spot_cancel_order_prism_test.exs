defmodule Lux.Prisms.Binance.Spot.BinanceSpotCancelOrderPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Spot.BinanceSpotCancelOrderPrism

  describe "schema validation" do
    test "validates input schema" do
      prism = BinanceSpotCancelOrderPrism.view()

      assert prism.input_schema.type == :object
      assert "symbol" in prism.input_schema.required

      # Check properties
      assert Map.has_key?(prism.input_schema.properties, :symbol)
      assert Map.has_key?(prism.input_schema.properties, :order_id)
      assert Map.has_key?(prism.input_schema.properties, :orig_client_order_id)
    end

    test "validates output schema" do
      prism = BinanceSpotCancelOrderPrism.view()

      assert prism.output_schema.type == :object
      assert "status" in prism.output_schema.required
      assert "order" in prism.output_schema.required
    end

    test "prism has correct metadata" do
      prism = BinanceSpotCancelOrderPrism.view()

      assert prism.name == "Binance Spot Cancel Order"
      assert prism.description == "Cancels spot orders on Binance exchange"
    end
  end

  describe "handler/2 error cases" do
    test "returns error when API key is not configured" do
      Application.put_env(:lux, :accounts, [])

      result = BinanceSpotCancelOrderPrism.handler(%{
        symbol: "BTCUSDT",
        order_id: 123456
      }, %{})

      assert {:error, "Binance API key is not configured"} = result
    end
  end
end

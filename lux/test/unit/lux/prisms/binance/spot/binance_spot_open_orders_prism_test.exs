defmodule Lux.Prisms.Binance.Spot.BinanceSpotOpenOrdersPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Spot.BinanceSpotOpenOrdersPrism

  describe "schema validation" do
    test "validates input schema" do
      prism = BinanceSpotOpenOrdersPrism.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == []

      # Symbol is optional
      assert Map.has_key?(prism.input_schema.properties, :symbol)
    end

    test "validates output schema" do
      prism = BinanceSpotOpenOrdersPrism.view()

      assert prism.output_schema.type == :object
      assert "status" in prism.output_schema.required
      assert "orders" in prism.output_schema.required
    end

    test "prism has correct metadata" do
      prism = BinanceSpotOpenOrdersPrism.view()

      assert prism.name == "Binance Spot Open Orders"
      assert prism.description == "Fetches open spot orders from Binance exchange"
    end
  end

  describe "handler/2 error cases" do
    test "returns error when API key is not configured" do
      Application.put_env(:lux, :accounts, [])

      result = BinanceSpotOpenOrdersPrism.handler(%{}, %{})

      assert {:error, "Binance API key is not configured"} = result
    end
  end
end

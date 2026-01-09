defmodule Lux.Prisms.Binance.Futures.BinanceFuturesPositionPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Futures.BinanceFuturesPositionPrism

  describe "schema validation" do
    test "validates input schema" do
      prism = BinanceFuturesPositionPrism.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == []

      # Symbol is optional
      assert Map.has_key?(prism.input_schema.properties, :symbol)
    end

    test "validates output schema" do
      prism = BinanceFuturesPositionPrism.view()

      assert prism.output_schema.type == :object
      assert "status" in prism.output_schema.required
      assert "positions" in prism.output_schema.required
    end

    test "prism has correct metadata" do
      prism = BinanceFuturesPositionPrism.view()

      assert prism.name == "Binance Futures Position"
      assert prism.description == "Fetches futures position information from Binance exchange"
    end
  end

  describe "handler/2 error cases" do
    test "returns error when API key is not configured" do
      Application.put_env(:lux, :accounts, [])

      result = BinanceFuturesPositionPrism.handler(%{}, %{})

      assert {:error, "Binance API key is not configured"} = result
    end
  end
end

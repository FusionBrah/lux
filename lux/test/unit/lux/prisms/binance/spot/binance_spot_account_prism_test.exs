defmodule Lux.Prisms.Binance.Spot.BinanceSpotAccountPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Spot.BinanceSpotAccountPrism

  describe "schema validation" do
    test "validates input schema" do
      prism = BinanceSpotAccountPrism.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == []
    end

    test "validates output schema" do
      prism = BinanceSpotAccountPrism.view()

      assert prism.output_schema.type == :object
      assert "status" in prism.output_schema.required
      assert "account" in prism.output_schema.required
      assert Map.has_key?(prism.output_schema.properties, :status)
      assert Map.has_key?(prism.output_schema.properties, :account)
    end

    test "prism has correct metadata" do
      prism = BinanceSpotAccountPrism.view()

      assert prism.name == "Binance Spot Account"
      assert prism.description == "Fetches spot account information from Binance exchange"
    end
  end

  describe "handler/2 error cases" do
    test "returns error when API key is not configured" do
      # Clear any existing config
      Application.put_env(:lux, :accounts, [])

      result = BinanceSpotAccountPrism.handler(%{}, %{})

      assert {:error, "Binance API key is not configured"} = result
    end
  end
end

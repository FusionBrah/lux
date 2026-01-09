defmodule Lux.Lenses.Binance.BinanceTickerPriceLens do
  @moduledoc """
  Lens for fetching current ticker prices from the Binance API.

  This is a read-only lens that fetches price data from Binance's public API.
  No authentication is required.

  ## Example

      # Get price for a specific symbol
      alias Lux.Lenses.Binance.BinanceTickerPriceLens

      BinanceTickerPriceLens.focus(%{symbol: "BTCUSDT"})
      # => {:ok, %{symbol: "BTCUSDT", price: "42000.00000000"}}

      # Get prices for all symbols (no symbol parameter)
      BinanceTickerPriceLens.focus(%{})
      # => {:ok, %{prices: [%{symbol: "BTCUSDT", price: "42000.00"}, ...]}}
  """

  alias Lux.Config

  use Lux.Lens,
    name: "Binance Ticker Price",
    description: "Fetches current ticker prices from Binance exchange",
    url: "https://api.binance.com/api/v3/ticker/price",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{type: :none},
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT'). If not provided, returns all prices."
        }
      },
      required: []
    }

  @doc """
  Override focus to use dynamic URL based on testnet configuration.
  """
  def focus(input, opts) do
    base_url = Config.binance_spot_url()

    view()
    |> Map.put(:url, "#{base_url}/api/v3/ticker/price")
    |> Map.update!(:params, &Map.merge(&1, input))
    |> Lux.Lens.authenticate()
    |> Map.update!(:params, &before_focus(&1))
    |> Lux.Lens.focus(opts)
  end

  @doc """
  Transforms the API response into a standardized format.
  """
  @impl true
  def after_focus(response) when is_map(response) and not is_map_key(response, "code") do
    # Single symbol response
    {:ok, %{
      symbol: response["symbol"],
      price: response["price"]
    }}
  end

  @impl true
  def after_focus(response) when is_list(response) do
    # Multiple symbols response
    prices = Enum.map(response, fn item ->
      %{
        symbol: item["symbol"],
        price: item["price"]
      }
    end)

    {:ok, %{prices: prices}}
  end

  @impl true
  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, "Binance API error #{code}: #{msg}"}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end

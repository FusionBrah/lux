defmodule Lux.Lenses.Binance.BinanceExchangeInfoLens do
  @moduledoc """
  Lens for fetching exchange information from the Binance API.

  This is a read-only lens that fetches exchange info including trading rules,
  symbols, and rate limits from Binance's public API.
  No authentication is required.

  ## Example

      # Get info for a specific symbol
      alias Lux.Lenses.Binance.BinanceExchangeInfoLens

      BinanceExchangeInfoLens.focus(%{symbol: "BTCUSDT"})
      # => {:ok, %{
      #      timezone: "UTC",
      #      server_time: 1234567890123,
      #      symbols: [%{symbol: "BTCUSDT", status: "TRADING", ...}]
      #    }}

      # Get all exchange info
      BinanceExchangeInfoLens.focus(%{})
  """

  alias Lux.Config

  use Lux.Lens,
    name: "Binance Exchange Info",
    description: "Fetches exchange information from Binance including trading rules and symbols",
    url: "https://api.binance.com/api/v3/exchangeInfo",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{type: :none},
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT'). If not provided, returns all symbols."
        },
        symbols: %{
          type: :array,
          description: "List of symbols to query (alternative to single symbol)",
          items: %{type: :string}
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
    |> Map.put(:url, "#{base_url}/api/v3/exchangeInfo")
    |> Map.update!(:params, &Map.merge(&1, input))
    |> Lux.Lens.authenticate()
    |> Map.update!(:params, &before_focus(&1))
    |> Lux.Lens.focus(opts)
  end

  @doc """
  Transform parameters before the request.
  Converts symbols array to comma-separated string if provided.
  """
  def before_focus(params) do
    case Map.get(params, :symbols) do
      nil -> params
      symbols when is_list(symbols) ->
        # Convert to JSON array format for Binance API
        params
        |> Map.delete(:symbols)
        |> Map.put(:symbols, Jason.encode!(symbols))
      _ -> params
    end
  end

  @doc """
  Transforms the API response into a standardized format.
  """
  @impl true
  def after_focus(%{"timezone" => timezone, "serverTime" => server_time, "symbols" => symbols} = response) do
    transformed_symbols = Enum.map(symbols, fn symbol ->
      %{
        symbol: symbol["symbol"],
        status: symbol["status"],
        base_asset: symbol["baseAsset"],
        quote_asset: symbol["quoteAsset"],
        base_asset_precision: symbol["baseAssetPrecision"],
        quote_asset_precision: symbol["quoteAssetPrecision"],
        order_types: symbol["orderTypes"],
        filters: symbol["filters"]
      }
    end)

    {:ok, %{
      timezone: timezone,
      server_time: server_time,
      rate_limits: Map.get(response, "rateLimits", []),
      symbols: transformed_symbols
    }}
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

defmodule Lux.Prisms.Binance.Spot.BinanceSpotOpenOrdersPrism do
  @moduledoc """
  A prism that fetches open spot orders from the Binance exchange.

  ## Example

      # Get all open orders
      iex> Lux.Prisms.Binance.Spot.BinanceSpotOpenOrdersPrism.run(%{})
      {:ok,
       %{
         status: "success",
         orders: [
           %{
             "orderId" => 123456,
             "symbol" => "BTCUSDT",
             "side" => "BUY",
             "type" => "LIMIT",
             "price" => "40000.00",
             "origQty" => "0.001",
             "executedQty" => "0.0",
             "status" => "NEW"
           }
         ]
       }}

      # Get open orders for a specific symbol
      iex> Lux.Prisms.Binance.Spot.BinanceSpotOpenOrdersPrism.run(%{symbol: "BTCUSDT"})

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Spot Open Orders",
    description: "Fetches open spot orders from Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol to filter by (e.g., 'BTCUSDT'). If not provided, returns all open orders."
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        orders: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              orderId: %{type: :integer},
              symbol: %{type: :string},
              side: %{type: :string},
              type: %{type: :string},
              price: %{type: :string},
              origQty: %{type: :string},
              executedQty: %{type: :string},
              status: %{type: :string}
            }
          }
        }
      },
      required: ["status", "orders"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol")

    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, base_url} <- {:ok, Config.binance_spot_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.spot"),
         {:ok, result} <- fetch_open_orders(api_key, api_secret, base_url, symbol) do
      {:ok, %{status: "success", orders: result}}
    else
      {:error, :missing_api_key} ->
        {:error, "Binance API key is not configured"}

      {:error, :missing_api_secret} ->
        {:error, "Binance API secret is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_api_key do
    {:ok, Config.binance_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    {:ok, Config.binance_api_secret()}
  rescue
    RuntimeError -> {:error, :missing_api_secret}
  end

  defp fetch_open_orders(api_key, api_secret, base_url, symbol) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               base_url: base_url,
               symbol: symbol
             } do
        ~PY"""
        from binance_utils.spot import get_spot_client, get_open_spot_orders

        client = get_spot_client(api_key, api_secret, base_url)
        orders = get_open_spot_orders(client, symbol)
        orders  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
    end
  end
end

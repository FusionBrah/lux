defmodule Lux.Prisms.Binance.Futures.BinanceFuturesOrderPrism do
  @moduledoc """
  A prism that places futures orders on the Binance exchange.

  ## Example

      # Market order
      iex> Lux.Prisms.Binance.Futures.BinanceFuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "MARKET",
      ...>   quantity: 0.01
      ...> })
      {:ok,
       %{
         status: "success",
         order: %{
           "orderId" => 123456,
           "symbol" => "BTCUSDT",
           "status" => "FILLED",
           "avgPrice" => "42000.00",
           "executedQty" => "0.01",
           "cumQuote" => "420.00"
         }
       }}

      # Limit order with position side
      iex> Lux.Prisms.Binance.Futures.BinanceFuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: 0.01,
      ...>   price: 40000.0,
      ...>   time_in_force: "GTC",
      ...>   position_side: "LONG"
      ...> })

      # Stop market order (stop loss)
      iex> Lux.Prisms.Binance.Futures.BinanceFuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "SELL",
      ...>   type: "STOP_MARKET",
      ...>   quantity: 0.01,
      ...>   stop_price: 39000.0,
      ...>   reduce_only: true
      ...> })

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Futures Order",
    description: "Places futures orders on Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        side: %{
          type: :string,
          description: "Order side",
          enum: ["BUY", "SELL"]
        },
        type: %{
          type: :string,
          description: "Order type",
          enum: ["LIMIT", "MARKET", "STOP", "STOP_MARKET", "TAKE_PROFIT", "TAKE_PROFIT_MARKET", "TRAILING_STOP_MARKET"]
        },
        quantity: %{
          type: :number,
          description: "Order quantity"
        },
        price: %{
          type: :number,
          description: "Limit price (required for LIMIT orders)"
        },
        position_side: %{
          type: :string,
          description: "Position side for hedge mode",
          enum: ["BOTH", "LONG", "SHORT"],
          default: "BOTH"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force",
          enum: ["GTC", "IOC", "FOK", "GTX"],
          default: "GTC"
        },
        stop_price: %{
          type: :number,
          description: "Stop price for stop orders"
        },
        reduce_only: %{
          type: :boolean,
          description: "Whether the order should only reduce position",
          default: false
        },
        close_position: %{
          type: :boolean,
          description: "Close all position when triggered",
          default: false
        }
      },
      required: ["symbol", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order: %{
          type: :object,
          properties: %{
            orderId: %{type: :integer},
            symbol: %{type: :string},
            status: %{type: :string},
            avgPrice: %{type: :string},
            executedQty: %{type: :string},
            cumQuote: %{type: :string}
          }
        }
      },
      required: ["status", "order"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, base_url} <- {:ok, Config.binance_futures_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.um_futures"),
         {:ok, result} <- place_order(api_key, api_secret, base_url, input) do
      {:ok, %{status: "success", order: result}}
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

  defp place_order(api_key, api_secret, base_url, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               base_url: base_url,
               params: normalize_params(params)
             } do
        ~PY"""
        from binance_utils.futures import get_futures_client, place_futures_order

        client = get_futures_client(api_key, api_secret, base_url)

        # Build order parameters
        symbol = params["symbol"]
        side = params["side"]
        order_type = params["type"]
        quantity = params["quantity"]

        # Optional parameters
        kwargs = {}
        if "price" in params and params["price"]:
            kwargs["price"] = params["price"]
        if "position_side" in params and params["position_side"]:
            kwargs["positionSide"] = params["position_side"]
        if "time_in_force" in params and params["time_in_force"]:
            kwargs["timeInForce"] = params["time_in_force"]
        if "stop_price" in params and params["stop_price"]:
            kwargs["stopPrice"] = params["stop_price"]
        if "reduce_only" in params and params["reduce_only"]:
            kwargs["reduceOnly"] = "true"
        if "close_position" in params and params["close_position"]:
            kwargs["closePosition"] = "true"

        order = place_futures_order(client, symbol, side, order_type, quantity, **kwargs)
        order  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp normalize_params(params) do
    params
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end
end

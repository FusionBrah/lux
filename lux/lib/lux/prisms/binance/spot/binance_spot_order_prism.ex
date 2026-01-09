defmodule Lux.Prisms.Binance.Spot.BinanceSpotOrderPrism do
  @moduledoc """
  A prism that places spot orders on the Binance exchange.

  ## Example

      # Market order
      iex> Lux.Prisms.Binance.Spot.BinanceSpotOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "MARKET",
      ...>   quantity: 0.001
      ...> })
      {:ok,
       %{
         status: "success",
         order: %{
           "orderId" => 123456,
           "symbol" => "BTCUSDT",
           "status" => "FILLED",
           "executedQty" => "0.001",
           "cummulativeQuoteQty" => "42.00",
           "fills" => [...]
         }
       }}

      # Limit order
      iex> Lux.Prisms.Binance.Spot.BinanceSpotOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: 0.001,
      ...>   price: 40000.0,
      ...>   time_in_force: "GTC"
      ...> })

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Spot Order",
    description: "Places spot orders on Binance exchange",
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
          enum: ["LIMIT", "MARKET", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", "TAKE_PROFIT_LIMIT", "LIMIT_MAKER"]
        },
        quantity: %{
          type: :number,
          description: "Order quantity in base asset"
        },
        price: %{
          type: :number,
          description: "Limit price (required for LIMIT orders)"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force",
          enum: ["GTC", "IOC", "FOK"],
          default: "GTC"
        },
        stop_price: %{
          type: :number,
          description: "Stop price for stop orders"
        },
        quote_order_qty: %{
          type: :number,
          description: "Quote order quantity for MARKET orders (alternative to quantity)"
        }
      },
      required: ["symbol", "side", "type"]
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
            executedQty: %{type: :string},
            cummulativeQuoteQty: %{type: :string},
            fills: %{type: :array}
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
         {:ok, base_url} <- {:ok, Config.binance_spot_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.spot"),
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
        from binance_utils.spot import get_spot_client, place_spot_order

        client = get_spot_client(api_key, api_secret, base_url)

        # Build order parameters
        symbol = params["symbol"]
        side = params["side"]
        order_type = params["type"]
        quantity = params.get("quantity")

        # Optional parameters
        kwargs = {}
        if "price" in params and params["price"]:
            kwargs["price"] = params["price"]
        if "time_in_force" in params and params["time_in_force"]:
            kwargs["timeInForce"] = params["time_in_force"]
        if "stop_price" in params and params["stop_price"]:
            kwargs["stopPrice"] = params["stop_price"]
        if "quote_order_qty" in params and params["quote_order_qty"]:
            kwargs["quoteOrderQty"] = params["quote_order_qty"]

        order = place_spot_order(client, symbol, side, order_type, quantity, **kwargs)
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

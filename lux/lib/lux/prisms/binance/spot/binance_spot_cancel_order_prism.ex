defmodule Lux.Prisms.Binance.Spot.BinanceSpotCancelOrderPrism do
  @moduledoc """
  A prism that cancels spot orders on the Binance exchange.

  ## Example

      # Cancel by order ID
      iex> Lux.Prisms.Binance.Spot.BinanceSpotCancelOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   order_id: 123456
      ...> })
      {:ok,
       %{
         status: "success",
         order: %{
           "orderId" => 123456,
           "symbol" => "BTCUSDT",
           "status" => "CANCELED",
           "origQty" => "0.001",
           "executedQty" => "0.0"
         }
       }}

      # Cancel by client order ID
      iex> Lux.Prisms.Binance.Spot.BinanceSpotCancelOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   orig_client_order_id: "my-order-123"
      ...> })

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Spot Cancel Order",
    description: "Cancels spot orders on Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        order_id: %{
          type: :integer,
          description: "Exchange order ID"
        },
        orig_client_order_id: %{
          type: :string,
          description: "Original client order ID"
        }
      },
      required: ["symbol"]
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
            origQty: %{type: :string},
            executedQty: %{type: :string}
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
         {:ok, result} <- cancel_order(api_key, api_secret, base_url, input) do
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

  defp cancel_order(api_key, api_secret, base_url, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               base_url: base_url,
               params: normalize_params(params)
             } do
        ~PY"""
        from binance_utils.spot import get_spot_client, cancel_spot_order

        client = get_spot_client(api_key, api_secret, base_url)

        symbol = params["symbol"]
        order_id = params.get("order_id")
        orig_client_order_id = params.get("orig_client_order_id")

        result = cancel_spot_order(client, symbol, order_id, orig_client_order_id)
        result  # Return the result
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

defmodule Lux.Prisms.Binance.Futures.BinanceFuturesPositionPrism do
  @moduledoc """
  A prism that fetches futures position information from the Binance exchange.

  ## Example

      # Get all positions
      iex> Lux.Prisms.Binance.Futures.BinanceFuturesPositionPrism.run(%{})
      {:ok,
       %{
         status: "success",
         positions: [
           %{
             "symbol" => "BTCUSDT",
             "positionAmt" => "0.1",
             "entryPrice" => "42000.0",
             "markPrice" => "42500.0",
             "unRealizedProfit" => "50.00",
             "liquidationPrice" => "35000.0",
             "leverage" => "10",
             "marginType" => "cross",
             "positionSide" => "BOTH"
           }
         ]
       }}

      # Get position for a specific symbol
      iex> Lux.Prisms.Binance.Futures.BinanceFuturesPositionPrism.run(%{symbol: "BTCUSDT"})

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Futures Position",
    description: "Fetches futures position information from Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol to filter by (e.g., 'BTCUSDT'). If not provided, returns all positions."
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        positions: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              symbol: %{type: :string},
              positionAmt: %{type: :string},
              entryPrice: %{type: :string},
              markPrice: %{type: :string},
              unRealizedProfit: %{type: :string},
              liquidationPrice: %{type: :string},
              leverage: %{type: :string},
              marginType: %{type: :string},
              positionSide: %{type: :string}
            }
          }
        }
      },
      required: ["status", "positions"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol")

    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, base_url} <- {:ok, Config.binance_futures_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.um_futures"),
         {:ok, result} <- fetch_positions(api_key, api_secret, base_url, symbol) do
      {:ok, %{status: "success", positions: result}}
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

  defp fetch_positions(api_key, api_secret, base_url, symbol) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               base_url: base_url,
               symbol: symbol
             } do
        ~PY"""
        from binance_utils.futures import get_futures_client, get_futures_positions

        client = get_futures_client(api_key, api_secret, base_url)
        positions = get_futures_positions(client, symbol)
        positions  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
    end
  end
end

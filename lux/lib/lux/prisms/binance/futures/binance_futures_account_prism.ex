defmodule Lux.Prisms.Binance.Futures.BinanceFuturesAccountPrism do
  @moduledoc """
  A prism that fetches futures account information from the Binance exchange.

  ## Example

      iex> Lux.Prisms.Binance.Futures.BinanceFuturesAccountPrism.run(%{})
      {:ok,
       %{
         status: "success",
         account: %{
           "totalWalletBalance" => "1000.00",
           "totalUnrealizedProfit" => "50.00",
           "totalMarginBalance" => "1050.00",
           "availableBalance" => "800.00",
           "positions" => [
             %{
               "symbol" => "BTCUSDT",
               "positionAmt" => "0.1",
               "entryPrice" => "42000.0",
               "unrealizedProfit" => "50.00",
               "leverage" => "10"
             }
           ],
           "assets" => [
             %{
               "asset" => "USDT",
               "walletBalance" => "1000.00",
               "availableBalance" => "800.00"
             }
           ]
         }
       }}

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Futures Account",
    description: "Fetches futures account information from Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        account: %{
          type: :object,
          properties: %{
            totalWalletBalance: %{type: :string},
            totalUnrealizedProfit: %{type: :string},
            totalMarginBalance: %{type: :string},
            availableBalance: %{type: :string},
            positions: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  symbol: %{type: :string},
                  positionAmt: %{type: :string},
                  entryPrice: %{type: :string},
                  unrealizedProfit: %{type: :string},
                  leverage: %{type: :string}
                }
              }
            },
            assets: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  asset: %{type: :string},
                  walletBalance: %{type: :string},
                  availableBalance: %{type: :string}
                }
              }
            }
          }
        }
      },
      required: ["status", "account"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(_input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, base_url} <- {:ok, Config.binance_futures_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.um_futures"),
         {:ok, result} <- fetch_account(api_key, api_secret, base_url) do
      {:ok, %{status: "success", account: result}}
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

  defp fetch_account(api_key, api_secret, base_url) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               base_url: base_url
             } do
        ~PY"""
        from binance_utils.futures import get_futures_client, get_futures_account

        client = get_futures_client(api_key, api_secret, base_url)
        account = get_futures_account(client)
        account  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

defmodule Lux.Prisms.Binance.Spot.BinanceSpotAccountPrism do
  @moduledoc """
  A prism that fetches spot account information from the Binance exchange.

  ## Example

      iex> Lux.Prisms.Binance.Spot.BinanceSpotAccountPrism.run(%{})
      {:ok,
       %{
         status: "success",
         account: %{
           "balances" => [
             %{"asset" => "BTC", "free" => "0.001", "locked" => "0.0"},
             %{"asset" => "USDT", "free" => "100.0", "locked" => "0.0"}
           ],
           "canTrade" => true,
           "canWithdraw" => true,
           "canDeposit" => true,
           # ... other account fields
         }
       }}

  The prism reads authentication details from configuration:
  - :binance_api_key - Binance API key
  - :binance_api_secret - Binance API secret
  - :binance_testnet - Whether to use testnet (optional)
  """

  use Lux.Prism,
    name: "Binance Spot Account",
    description: "Fetches spot account information from Binance exchange",
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
            balances: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  asset: %{type: :string},
                  free: %{type: :string},
                  locked: %{type: :string}
                }
              }
            },
            canTrade: %{type: :boolean},
            canWithdraw: %{type: :boolean},
            canDeposit: %{type: :boolean}
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
         {:ok, base_url} <- {:ok, Config.binance_spot_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.spot"),
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
        from binance_utils.spot import get_spot_client, get_spot_account

        client = get_spot_client(api_key, api_secret, base_url)
        account = get_spot_account(client)
        account  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

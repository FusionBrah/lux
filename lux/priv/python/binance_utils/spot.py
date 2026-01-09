"""
Binance Spot trading utilities for the Lux framework.

This module provides helper functions for interacting with the Binance Spot API
using the official binance-connector-python SDK.
"""

from typing import Any, Optional

from binance.error import ClientError, ServerError
from binance.spot import Spot

# Default timeout in seconds for API requests
DEFAULT_TIMEOUT = 10


def get_spot_client(
    api_key: str,
    api_secret: str,
    base_url: Optional[str] = None,
    timeout: int = DEFAULT_TIMEOUT,
) -> Spot:
    """
    Create an authenticated Binance Spot client.

    Args:
        api_key: Binance API key
        api_secret: Binance API secret
        base_url: Optional base URL (use for testnet)
        timeout: Request timeout in seconds (default: 10)

    Returns:
        Binance Spot client instance
    """
    kwargs: dict[str, Any] = {
        "api_key": api_key,
        "api_secret": api_secret,
        "timeout": timeout,
    }
    if base_url:
        kwargs["base_url"] = base_url
    return Spot(**kwargs)


def place_spot_order(
    client: Spot,
    symbol: str,
    side: str,
    order_type: str,
    quantity: Optional[float] = None,
    **kwargs: Any,
) -> dict[str, Any]:
    """
    Place a spot order on Binance.

    Args:
        client: Binance Spot client
        symbol: Trading pair (e.g., "BTCUSDT")
        side: Order side ("BUY" or "SELL")
        order_type: Order type ("LIMIT", "MARKET", etc.)
        quantity: Order quantity
        **kwargs: Additional order parameters (price, timeInForce, etc.)

    Returns:
        Order response from Binance API, or error dict on failure
    """
    try:
        params: dict[str, Any] = {
            "symbol": symbol,
            "side": side,
            "type": order_type,
        }
        if quantity is not None:
            params["quantity"] = quantity
        params.update(kwargs)
        return client.new_order(**params)
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def cancel_spot_order(
    client: Spot,
    symbol: str,
    order_id: Optional[int] = None,
    orig_client_order_id: Optional[str] = None,
) -> dict[str, Any]:
    """
    Cancel a spot order on Binance.

    Args:
        client: Binance Spot client
        symbol: Trading pair
        order_id: Exchange order ID (optional if orig_client_order_id provided)
        orig_client_order_id: Client order ID (optional if order_id provided)

    Returns:
        Cancellation response from Binance API, or error dict on failure
    """
    try:
        params: dict[str, Any] = {"symbol": symbol}
        if order_id:
            params["orderId"] = order_id
        if orig_client_order_id:
            params["origClientOrderId"] = orig_client_order_id
        return client.cancel_order(**params)
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def get_spot_account(client: Spot) -> dict[str, Any]:
    """
    Get spot account information including balances.

    Args:
        client: Binance Spot client

    Returns:
        Account information from Binance API, or error dict on failure
    """
    try:
        return client.account()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def get_open_spot_orders(
    client: Spot,
    symbol: Optional[str] = None,
) -> list[dict[str, Any]] | dict[str, Any]:
    """
    Get open spot orders.

    Args:
        client: Binance Spot client
        symbol: Optional trading pair to filter by

    Returns:
        List of open orders, or error dict on failure
    """
    try:
        if symbol:
            return client.get_open_orders(symbol=symbol)
        return client.get_open_orders()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def get_ticker_price(
    client: Spot,
    symbol: Optional[str] = None,
) -> dict[str, Any] | list[dict[str, Any]]:
    """
    Get current ticker price(s).

    Args:
        client: Binance Spot client
        symbol: Optional trading pair (returns all if not specified)

    Returns:
        Price data (single dict or list of dicts), or error dict on failure
    """
    try:
        if symbol:
            return client.ticker_price(symbol=symbol)
        return client.ticker_price()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def get_exchange_info(
    client: Spot,
    symbol: Optional[str] = None,
) -> dict[str, Any]:
    """
    Get exchange information including trading rules and symbols.

    Args:
        client: Binance Spot client
        symbol: Optional symbol to get specific info for

    Returns:
        Exchange information from Binance API, or error dict on failure
    """
    try:
        if symbol:
            return client.exchange_info(symbol=symbol)
        return client.exchange_info()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}

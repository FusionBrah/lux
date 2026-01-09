"""
Binance Futures trading utilities for the Lux framework.

This module provides helper functions for interacting with the Binance USD-M Futures API
using the official binance-futures-connector-python SDK.
"""

from typing import Any, Optional

from binance.error import ClientError, ServerError
from binance.um_futures import UMFutures

# Default timeout in seconds for API requests
DEFAULT_TIMEOUT = 10


def get_futures_client(
    api_key: str,
    api_secret: str,
    base_url: Optional[str] = None,
    timeout: int = DEFAULT_TIMEOUT,
) -> UMFutures:
    """
    Create an authenticated Binance USD-M Futures client.

    Args:
        api_key: Binance API key
        api_secret: Binance API secret
        base_url: Optional base URL (use for testnet)
        timeout: Request timeout in seconds (default: 10)

    Returns:
        Binance USD-M Futures client instance
    """
    kwargs: dict[str, Any] = {
        "key": api_key,
        "secret": api_secret,
        "timeout": timeout,
    }
    if base_url:
        kwargs["base_url"] = base_url
    return UMFutures(**kwargs)


def place_futures_order(
    client: UMFutures,
    symbol: str,
    side: str,
    order_type: str,
    quantity: float,
    **kwargs: Any,
) -> dict[str, Any]:
    """
    Place a futures order on Binance.

    Args:
        client: Binance Futures client
        symbol: Trading pair (e.g., "BTCUSDT")
        side: Order side ("BUY" or "SELL")
        order_type: Order type ("LIMIT", "MARKET", "STOP", etc.)
        quantity: Order quantity
        **kwargs: Additional order parameters (price, positionSide, reduceOnly, etc.)

    Returns:
        Order response from Binance API, or error dict on failure
    """
    try:
        params: dict[str, Any] = {
            "symbol": symbol,
            "side": side,
            "type": order_type,
            "quantity": quantity,
        }
        params.update(kwargs)
        return client.new_order(**params)
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def cancel_futures_order(
    client: UMFutures,
    symbol: str,
    order_id: Optional[int] = None,
    orig_client_order_id: Optional[str] = None,
) -> dict[str, Any]:
    """
    Cancel a futures order on Binance.

    Args:
        client: Binance Futures client
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


def get_futures_account(client: UMFutures) -> dict[str, Any]:
    """
    Get futures account information including balances and positions.

    Args:
        client: Binance Futures client

    Returns:
        Account information from Binance API, or error dict on failure
    """
    try:
        return client.account()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}


def get_futures_positions(
    client: UMFutures,
    symbol: Optional[str] = None,
) -> list[dict[str, Any]] | dict[str, Any]:
    """
    Get futures position risk information.

    Args:
        client: Binance Futures client
        symbol: Optional trading pair to filter by

    Returns:
        Position risk data (list of positions), or error dict on failure
    """
    try:
        if symbol:
            return client.get_position_risk(symbol=symbol)
        return client.get_position_risk()
    except ClientError as e:
        return {"error": e.error_message, "error_code": e.error_code, "status_code": e.status_code}
    except ServerError as e:
        return {"error": str(e), "error_code": -1, "status_code": getattr(e, "status_code", 500)}

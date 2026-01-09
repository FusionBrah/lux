"""
Binance utilities for the Lux framework.

This module provides helper functions for interacting with the Binance exchange
via the official binance-connector and binance-futures-connector Python SDKs.
"""

from binance_utils.spot import (
    get_spot_client,
    place_spot_order,
    cancel_spot_order,
    get_spot_account,
    get_open_spot_orders,
    get_ticker_price,
    get_exchange_info,
)

from binance_utils.futures import (
    get_futures_client,
    place_futures_order,
    cancel_futures_order,
    get_futures_account,
    get_futures_positions,
)

__all__ = [
    # Spot
    "get_spot_client",
    "place_spot_order",
    "cancel_spot_order",
    "get_spot_account",
    "get_open_spot_orders",
    "get_ticker_price",
    "get_exchange_info",
    # Futures
    "get_futures_client",
    "place_futures_order",
    "cancel_futures_order",
    "get_futures_account",
    "get_futures_positions",
]

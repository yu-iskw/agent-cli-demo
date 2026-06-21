# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Hotel search tools — deterministic mocks with optional live API path."""

from __future__ import annotations

import os
from typing import Any


def _mock_hotels(city: str) -> list[dict[str, Any]]:
    return [
        {
            "name": "Mesh Downtown Hotel",
            "city": city.title(),
            "nightly_usd": 189,
            "rating": 4.5,
        },
        {
            "name": "Demo Suites",
            "city": city.title(),
            "nightly_usd": 142,
            "rating": 4.1,
        },
    ]


def search_hotels(
    city: str, check_in: str = "2026-07-01", check_out: str = "2026-07-05"
) -> dict[str, Any]:
    """Search hotel availability in a city.

    Args:
        city: Destination city (e.g. San Francisco).
        check_in: Check-in date (ISO format).
        check_out: Check-out date (ISO format).

    Returns:
        Hotel options with name, price, and rating.
    """
    if os.environ.get("USE_LIVE_HOTEL_API", "").lower() == "true":
        return {
            "status": "live_api_not_configured",
            "message": "Set hotel API credentials in Secret Manager for live search.",
        }

    return {
        "status": "ok",
        "city": city,
        "check_in": check_in,
        "check_out": check_out,
        "hotels": _mock_hotels(city),
    }

# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Flight search tools — deterministic mocks with optional live API path."""

from __future__ import annotations

import os
from typing import Any


def _mock_flights(origin: str, destination: str) -> list[dict[str, Any]]:
    return [
        {
            "airline": "Mesh Air",
            "origin": origin.upper(),
            "destination": destination.upper(),
            "departure": "2026-07-01T08:00:00",
            "price_usd": 320,
            "stops": 0,
        },
        {
            "airline": "Demo Airways",
            "origin": origin.upper(),
            "destination": destination.upper(),
            "departure": "2026-07-01T14:30:00",
            "price_usd": 275,
            "stops": 1,
        },
    ]


def search_flights(origin: str, destination: str) -> dict[str, Any]:
    """Search available flights between two cities.

    Args:
        origin: Departure city or airport code (e.g. NYC).
        destination: Arrival city or airport code (e.g. SFO).

    Returns:
        Flight options with airline, times, and price.
    """
    if os.environ.get("USE_LIVE_FLIGHT_API", "").lower() == "true":
        # Live API: credentials from Secret Manager via env at deploy time.
        return {
            "status": "live_api_not_configured",
            "message": "Set flight API credentials in Secret Manager for live search.",
        }

    return {
        "status": "ok",
        "origin": origin,
        "destination": destination,
        "flights": _mock_flights(origin, destination),
    }

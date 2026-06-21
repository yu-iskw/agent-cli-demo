# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Delegation tools — auth-gated calls to flight/hotel specialists."""

from __future__ import annotations

import os
from typing import Any

from app.mesh_auth import (
    SPECIALIST_FLIGHT,
    SPECIALIST_HOTEL,
    auth_error_message,
    current_persona,
    mock_flight_delegate,
    mock_hotel_delegate,
    use_mesh_mocks,
    user_may_access_specialist,
)


def delegate_flight_search(origin: str, destination: str) -> dict[str, Any]:
    """Delegate flight search to the flight-researcher specialist.

    Args:
        origin: Departure city (e.g. NYC).
        destination: Arrival city (e.g. San Francisco).

    Returns:
        Flight options or AUTH_ERROR when persona lacks permission.
    """
    persona = current_persona()
    if not user_may_access_specialist(persona, SPECIALIST_FLIGHT):
        return {
            "status": "auth_denied",
            "message": auth_error_message(persona, SPECIALIST_FLIGHT),
        }

    if use_mesh_mocks() or not os.environ.get("FLIGHT_A2A_CARD_URL"):
        return mock_flight_delegate(origin, destination)

    return {
        "status": "a2a_required",
        "message": (
            "Start flight-researcher A2A server and set FLIGHT_A2A_CARD_URL, "
            "or set USE_MESH_MOCKS=true for local eval."
        ),
    }


def delegate_hotel_search(city: str) -> dict[str, Any]:
    """Delegate hotel search to the hotel-researcher specialist.

    Args:
        city: Destination city for lodging.

    Returns:
        Hotel options or AUTH_ERROR when persona lacks permission.
    """
    persona = current_persona()
    if not user_may_access_specialist(persona, SPECIALIST_HOTEL):
        return {
            "status": "auth_denied",
            "message": auth_error_message(persona, SPECIALIST_HOTEL),
        }

    if use_mesh_mocks() or not os.environ.get("HOTEL_A2A_CARD_URL"):
        return mock_hotel_delegate(city)

    return {
        "status": "a2a_required",
        "message": (
            "Start hotel-researcher A2A server and set HOTEL_A2A_CARD_URL, "
            "or set USE_MESH_MOCKS=true for local eval."
        ),
    }

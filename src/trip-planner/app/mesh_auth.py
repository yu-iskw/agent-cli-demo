# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Mesh governance and delegation for the trip-planner orchestrator."""

from __future__ import annotations

import os
from typing import Any, Final

SPECIALIST_FLIGHT: Final = "flight-researcher"
SPECIALIST_HOTEL: Final = "hotel-researcher"

PERSONA_ACCESS: dict[str, dict[str, bool]] = {
    "mesh-full-user": {SPECIALIST_FLIGHT: True, SPECIALIST_HOTEL: True},
    "mesh-flight-user": {SPECIALIST_FLIGHT: True, SPECIALIST_HOTEL: False},
    "mesh-hotel-user": {SPECIALIST_FLIGHT: False, SPECIALIST_HOTEL: True},
    "mesh-deny-user": {SPECIALIST_FLIGHT: False, SPECIALIST_HOTEL: False},
}


def current_persona(state_persona: str | None = None) -> str:
    if state_persona:
        return state_persona
    return os.environ.get("MESH_USER_PERSONA", "mesh-full-user")


def user_may_access_specialist(persona: str, specialist: str) -> bool:
    return PERSONA_ACCESS.get(persona, {}).get(specialist, False)


def user_may_use_trip_planner(persona: str) -> bool:
    return persona != "mesh-deny-user"


def auth_error_message(persona: str, specialist: str) -> str:
    return (
        f"AUTH_ERROR: persona '{persona}' is not permitted to use '{specialist}'. "
        "Contact an administrator to request access."
    )


def mock_flight_delegate(origin: str, destination: str) -> dict[str, Any]:
    return {
        "status": "ok",
        "source": "mock_delegate",
        "flights": [
            {
                "airline": "Mesh Air",
                "origin": origin.upper(),
                "destination": destination.upper(),
                "price_usd": 320,
            }
        ],
    }


def mock_hotel_delegate(city: str) -> dict[str, Any]:
    return {
        "status": "ok",
        "source": "mock_delegate",
        "hotels": [
            {"name": "Mesh Downtown Hotel", "city": city.title(), "nightly_usd": 189}
        ],
    }


def use_mesh_mocks() -> bool:
    return os.environ.get("USE_MESH_MOCKS", "true").lower() == "true"

# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Mesh governance helpers — per-agent user authorization."""

from __future__ import annotations

import os
from typing import Final

SPECIALIST_NAME: Final = "hotel-researcher"

PERSONA_ACCESS: dict[str, dict[str, bool]] = {
    "mesh-full-user": {"flight-researcher": True, "hotel-researcher": True},
    "mesh-flight-user": {"flight-researcher": True, "hotel-researcher": False},
    "mesh-hotel-user": {"flight-researcher": False, "hotel-researcher": True},
    "mesh-deny-user": {"flight-researcher": False, "hotel-researcher": False},
}


def current_persona(state_persona: str | None = None) -> str:
    if state_persona:
        return state_persona
    return os.environ.get("MESH_USER_PERSONA", "mesh-full-user")


def user_may_access_specialist(persona: str, specialist: str) -> bool:
    return PERSONA_ACCESS.get(persona, {}).get(specialist, False)


def auth_error_message(persona: str, specialist: str) -> str:
    return (
        f"AUTH_ERROR: persona '{persona}' is not permitted to use '{specialist}'. "
        "Contact an administrator to request access."
    )

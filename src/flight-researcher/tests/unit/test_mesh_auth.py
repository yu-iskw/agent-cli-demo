# Copyright 2026 yu-iskw

from app.mesh_auth import (
    auth_error_message,
    user_may_access_specialist,
)


def test_full_user_may_access_flight() -> None:
    assert user_may_access_specialist("mesh-full-user", "flight-researcher")


def test_flight_user_denied_hotel() -> None:
    assert user_may_access_specialist("mesh-flight-user", "flight-researcher")
    assert not user_may_access_specialist("mesh-flight-user", "hotel-researcher")


def test_deny_user_has_no_access() -> None:
    assert not user_may_access_specialist("mesh-deny-user", "flight-researcher")
    assert "AUTH_ERROR" in auth_error_message("mesh-deny-user", "flight-researcher")

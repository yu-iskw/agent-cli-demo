# Copyright 2026 yu-iskw

from app.mesh_auth import user_may_use_trip_planner
from app.tools import delegate_flight_search, delegate_hotel_search


def test_deny_user_cannot_use_trip_planner() -> None:
    assert not user_may_use_trip_planner("mesh-deny-user")


def test_flight_user_hotel_delegation_denied(monkeypatch) -> None:
    monkeypatch.setenv("MESH_USER_PERSONA", "mesh-flight-user")
    monkeypatch.setenv("USE_MESH_MOCKS", "true")
    result = delegate_hotel_search("San Francisco")
    assert result["status"] == "auth_denied"
    assert "AUTH_ERROR" in result["message"]


def test_full_user_delegation_ok(monkeypatch) -> None:
    monkeypatch.setenv("MESH_USER_PERSONA", "mesh-full-user")
    monkeypatch.setenv("USE_MESH_MOCKS", "true")
    flights = delegate_flight_search("NYC", "SFO")
    hotels = delegate_hotel_search("San Francisco")
    assert flights["status"] == "ok"
    assert hotels["status"] == "ok"

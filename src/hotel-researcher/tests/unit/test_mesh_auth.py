# Copyright 2026 yu-iskw

from app.mesh_auth import user_may_access_specialist


def test_hotel_user_denied_flight() -> None:
    assert user_may_access_specialist("mesh-hotel-user", "hotel-researcher")
    assert not user_may_access_specialist("mesh-hotel-user", "flight-researcher")

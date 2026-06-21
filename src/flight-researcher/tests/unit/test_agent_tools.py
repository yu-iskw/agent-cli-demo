# Copyright 2026 yu-iskw

from app.agent import root_agent
from app.tools import search_flights


def test_search_flights_returns_mock_options() -> None:
    result = search_flights("NYC", "SFO")
    assert result["status"] == "ok"
    assert len(result["flights"]) >= 1


def test_root_agent_exposes_search_flights_tool() -> None:
    tool_names = {getattr(tool, "__name__", str(tool)) for tool in root_agent.tools}
    assert tool_names == {"search_flights"}

# Copyright 2026 yu-iskw

from app.agent import root_agent
from app.tools import search_hotels


def test_search_hotels_returns_mock_options() -> None:
    result = search_hotels("San Francisco")
    assert result["status"] == "ok"
    assert len(result["hotels"]) >= 1


def test_root_agent_exposes_search_hotels_tool() -> None:
    tool_names = {getattr(tool, "__name__", str(tool)) for tool in root_agent.tools}
    assert tool_names == {"search_hotels"}

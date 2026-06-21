# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Load bundled A2A AgentCard specs for deployed mesh specialists."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Final

from a2a.types import AgentCard

_CARDS_DIR = Path(__file__).parent / "cards"

FLIGHT_CARD_FILE: Final = "flight-researcher-agent-card.json"
HOTEL_CARD_FILE: Final = "hotel-researcher-agent-card.json"


def load_agent_card(filename: str) -> AgentCard:
    """Load a specialist AgentCard baked into the orchestrator package."""
    path = _CARDS_DIR / filename
    data = json.loads(path.read_text(encoding="utf-8"))
    return AgentCard.model_validate(data)


def flight_agent_card() -> AgentCard:
    return load_agent_card(FLIGHT_CARD_FILE)


def hotel_agent_card() -> AgentCard:
    return load_agent_card(HOTEL_CARD_FILE)

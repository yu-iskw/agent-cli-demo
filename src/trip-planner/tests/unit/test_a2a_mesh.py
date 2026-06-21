# Copyright 2026 yu-iskw

from a2a.types import AgentCard

from app.agent import root_agent
from app.specialist_cards import flight_agent_card, hotel_agent_card, load_agent_card


def test_root_agent_has_a2a_sub_agents() -> None:
    assert len(root_agent.sub_agents) == 2
    names = {agent.name for agent in root_agent.sub_agents}
    assert names == {"flight_researcher", "hotel_researcher"}


def test_bundled_agent_cards_validate() -> None:
    flight = flight_agent_card()
    hotel = hotel_agent_card()
    assert isinstance(flight, AgentCard)
    assert isinstance(hotel, AgentCard)
    assert flight.url is not None
    assert hotel.url is not None
    assert "8436148099646226432" in str(flight.url)
    assert "787347082510860288" in str(hotel.url)


def test_load_agent_card_from_package() -> None:
    card = load_agent_card("flight-researcher-agent-card.json")
    assert card.name == "root_agent"

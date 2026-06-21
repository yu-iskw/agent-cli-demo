# ruff: noqa
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os

import google.auth
from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
from google.adk.apps import App
from google.adk.models import Gemini
from google.adk.tools import AgentTool
from google.genai import types

from app.mesh_auth import current_persona, user_may_use_trip_planner
from app.tools import delegate_flight_search, delegate_hotel_search

_, project_id = google.auth.default()
os.environ["GOOGLE_CLOUD_PROJECT"] = project_id
os.environ["GOOGLE_CLOUD_LOCATION"] = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"

DEFAULT_FLIGHT_CARD = "http://127.0.0.1:8001/a2a/app/.well-known/agent-card.json"
DEFAULT_HOTEL_CARD = "http://127.0.0.1:8002/a2a/app/.well-known/agent-card.json"


def _remote_agents() -> list[AgentTool]:
    """Remote A2A specialists when card URLs are configured and mocks disabled."""
    if os.environ.get("USE_MESH_MOCKS", "true").lower() == "true":
        return []

    tools: list[AgentTool] = []
    flight_card = os.environ.get("FLIGHT_A2A_CARD_URL", DEFAULT_FLIGHT_CARD)
    hotel_card = os.environ.get("HOTEL_A2A_CARD_URL", DEFAULT_HOTEL_CARD)

    flight_remote = RemoteA2aAgent(
        name="flight_researcher",
        description="Searches flights between cities via A2A.",
        agent_card=flight_card,
    )
    hotel_remote = RemoteA2aAgent(
        name="hotel_researcher",
        description="Searches hotels in a destination city via A2A.",
        agent_card=hotel_card,
    )
    tools.append(AgentTool(flight_remote))
    tools.append(AgentTool(hotel_remote))
    return tools


async def enforce_trip_planner_auth(callback_context: CallbackContext) -> None:
    persona = current_persona(callback_context.state.get("mesh_user_persona"))
    callback_context.state["mesh_user_persona"] = persona
    if not user_may_use_trip_planner(persona):
        callback_context.state["mesh_auth_denied"] = (
            f"AUTH_ERROR: persona '{persona}' is not permitted to use trip-planner."
        )


root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model="gemini-flash-latest",
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    description="Orchestrates trip planning by delegating to flight and hotel specialists.",
    instruction=(
        "You are the trip-planner orchestrator. For trips, call delegate_flight_search "
        "and delegate_hotel_search. If a tool returns auth_denied, explain the AUTH_ERROR "
        "to the user and continue with permitted sections only. "
        "If mesh_auth_denied is set in state, respond with that message. "
        "Produce a concise trip plan with flights and hotels when allowed."
    ),
    tools=[delegate_flight_search, delegate_hotel_search, *_remote_agents()],
    before_agent_callback=enforce_trip_planner_auth,
)

app = App(
    root_agent=root_agent,
    name="app",
)

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
# See the License for the License for the specific language governing permissions and
# limitations under the License.

import os

import google.auth
from google.adk.agents import Agent, SequentialAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types

from app.a2a_auth import create_authenticated_httpx_client
from app.specialist_cards import flight_agent_card, hotel_agent_card


def _configure_vertex_env() -> None:
    if "GOOGLE_CLOUD_PROJECT" not in os.environ:
        try:
            _, project_id = google.auth.default()
            if project_id:
                os.environ["GOOGLE_CLOUD_PROJECT"] = project_id
        except google.auth.exceptions.DefaultCredentialsError:
            pass
    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", "test-project")
    os.environ.setdefault("GOOGLE_CLOUD_LOCATION", "global")
    os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "True")


_configure_vertex_env()

_a2a_http_client = create_authenticated_httpx_client()

flight_researcher = RemoteA2aAgent(
    name="flight_researcher",
    description=(
        "Flight search specialist on Agent Platform. Delegate origin/destination "
        "flight queries here."
    ),
    agent_card=flight_agent_card(),
    httpx_client=_a2a_http_client,
    use_legacy=False,
)

hotel_researcher = RemoteA2aAgent(
    name="hotel_researcher",
    description=(
        "Hotel search specialist on Agent Platform. Delegate destination lodging "
        "queries here."
    ),
    agent_card=hotel_agent_card(),
    httpx_client=_a2a_http_client,
    use_legacy=False,
)

trip_synthesizer = Agent(
    name="trip_synthesizer",
    model=Gemini(
        model="gemini-3.1-flash-lite",
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    description="Combines flight and hotel specialist outputs into one trip plan.",
    instruction=(
        "Read the conversation history containing flight_researcher and hotel_researcher "
        "responses. Produce one concise trip plan with Flights and Hotels sections. "
        "Do not invent options not present in specialist responses."
    ),
)

root_agent = SequentialAgent(
    name="root_agent",
    description=(
        "Orchestrates trip planning: flight A2A specialist, hotel A2A specialist, "
        "then synthesis."
    ),
    sub_agents=[flight_researcher, hotel_researcher, trip_synthesizer],
)

app = App(
    root_agent=root_agent,
    name="app",
)

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
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types

from app.mesh_auth import (
    SPECIALIST_NAME,
    auth_error_message,
    current_persona,
    user_may_access_specialist,
)
from app.tools import search_hotels

_, project_id = google.auth.default()
os.environ["GOOGLE_CLOUD_PROJECT"] = project_id
os.environ["GOOGLE_CLOUD_LOCATION"] = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"


async def enforce_mesh_auth(callback_context: CallbackContext) -> None:
    """Reject requests when the user persona lacks hotel-researcher access."""
    persona = current_persona(callback_context.state.get("mesh_user_persona"))
    callback_context.state["mesh_user_persona"] = persona
    if not user_may_access_specialist(persona, SPECIALIST_NAME):
        callback_context.state["mesh_auth_denied"] = auth_error_message(
            persona, SPECIALIST_NAME
        )


root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model="gemini-flash-latest",
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    description="Searches hotels in a destination city for the trip-planner mesh.",
    instruction=(
        "You are the hotel-researcher specialist. Use search_hotels for lodging. "
        "If state mesh_auth_denied is set, respond with that message only. "
        "Summarize options with nightly rate and rating."
    ),
    tools=[search_hotels],
    before_agent_callback=enforce_mesh_auth,
)

app = App(
    root_agent=root_agent,
    name="app",
)

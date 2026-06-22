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
import google.auth.exceptions
from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types

from app.tools import search_hotels


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

root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model="gemini-3.1-flash-lite",
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    description="Searches hotels in a destination city for the trip-planner mesh.",
    instruction=(
        "You are the hotel-researcher specialist. Use search_hotels for lodging. "
        "Summarize options with nightly rate and rating."
    ),
    tools=[search_hotels],
)

app = App(
    root_agent=root_agent,
    name="app",
)

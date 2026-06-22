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

"""Workaround for Agent Runtime deploy introspection with Pydantic AgentCard."""

from __future__ import annotations

from collections.abc import Callable
from typing import TYPE_CHECKING, Any
from weakref import WeakKeyDictionary

from google.protobuf import json_format, struct_pb2

if TYPE_CHECKING:
    from a2a.types import AgentCard

_pydantic_cards: WeakKeyDictionary[Any, AgentCard] = WeakKeyDictionary()


def agent_card_proto_for_deploy(agent_card: AgentCard) -> struct_pb2.Struct:
    """Return a protobuf Struct vertexai can serialize during deploy introspection."""
    struct = struct_pb2.Struct()
    json_format.ParseDict(agent_card.model_dump(mode="json"), struct)
    return struct


def get_pydantic_agent_card(app: Any) -> AgentCard | None:
    """Return the real Pydantic card when a deploy shim is active."""
    return _pydantic_cards.get(app)


def install_deploy_agent_card_shim(app: Any, pydantic_card: AgentCard) -> None:
    """Swap agent_card to a protobuf shim until set_up restores the Pydantic card."""
    _pydantic_cards[app] = pydantic_card
    app.agent_card = agent_card_proto_for_deploy(pydantic_card)


def restore_pydantic_agent_card(app: Any) -> None:
    """Restore the real AgentCard before A2aAgent.set_up runs."""
    pydantic_card = _pydantic_cards.get(app)
    if pydantic_card is not None:
        app.agent_card = pydantic_card
        tmpl_attrs = getattr(app, "_tmpl_attrs", None)
        if tmpl_attrs is not None:
            tmpl_attrs["agent_card"] = pydantic_card


def run_register_operations_with_card(
    app: Any,
    pydantic_card: AgentCard,
    register: Callable[[], dict[str, list[str]]],
) -> dict[str, list[str]]:
    """Temporarily expose the Pydantic card while register_operations runs."""
    saved_card = app.agent_card
    app.agent_card = pydantic_card
    try:
        return register()
    finally:
        app.agent_card = saved_card

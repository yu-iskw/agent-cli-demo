# Copyright 2026 yu-iskw
# Licensed under the Apache License, Version 2.0

"""Google Cloud auth for outbound A2A calls to Agent Runtime specialists.

Pattern from Google codelab: Agents at Scale (ADK + A2A on Agent Runtime).
"""

from __future__ import annotations

import google.auth
import google.auth.transport.requests
import httpx

DEFAULT_A2A_TIMEOUT = 600.0


class GoogleCloudAuth(httpx.Auth):
    """Auto-refreshing Google Cloud authentication for httpx AsyncClient."""

    def __init__(self) -> None:
        self._credentials: google.auth.credentials.Credentials | None = None

    def _credentials_or_raise(self) -> google.auth.credentials.Credentials:
        if self._credentials is None:
            self._credentials, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
        return self._credentials

    def auth_flow(self, request: httpx.Request):
        credentials = self._credentials_or_raise()
        if not credentials.valid:
            credentials.refresh(google.auth.transport.requests.Request())
        request.headers["Authorization"] = f"Bearer {credentials.token}"
        yield request


def create_authenticated_httpx_client(
    timeout: float = DEFAULT_A2A_TIMEOUT,
) -> httpx.AsyncClient:
    """Build an httpx client that signs each request with ADC."""
    return httpx.AsyncClient(
        auth=GoogleCloudAuth(),
        timeout=httpx.Timeout(timeout=timeout),
    )

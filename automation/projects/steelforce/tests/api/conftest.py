"""Fixtures for SteelForce API tests. The generic ones (run context, API client,
``secret``) come from ``automation.api.pytest_plugin``."""

from collections.abc import Callable
from typing import Any

import pytest

from automation.api.client import ApiClient
from automation.core.config import RunContext
from automation.mobile.app_info import app_version
from steelforce.api.auth import AuthApi, Session, session_from

# Secret NAMES (declared in project.yaml). Values come from .env.<environment>
# or the process environment — never write a value here.
PRIMARY_PHONE = "STEELFORCE_QA_REP_PRIMARY_PHONE"
PRIMARY_PASSWORD = "STEELFORCE_QA_REP_PRIMARY_PASSWORD"
LOCKOUT_PHONE = "STEELFORCE_QA_LOCKOUT_PHONE"
LOCKOUT_PASSWORD = "STEELFORCE_QA_LOCKOUT_PASSWORD"


@pytest.fixture
def auth_api(api_client: ApiClient, run_context: RunContext) -> AuthApi:
    return AuthApi(api_client, app_version(run_context.flutter_dir))


@pytest.fixture
def primary_account(secret: Callable[[str], str]) -> tuple[str, str]:
    """TD-001 — active field rep."""
    return secret(PRIMARY_PHONE), secret(PRIMARY_PASSWORD)


@pytest.fixture
def lockout_account(secret: Callable[[str], str]) -> tuple[str, str]:
    """Throwaway account for wrong-password tests. Never TD-001."""
    return secret(LOCKOUT_PHONE), secret(LOCKOUT_PASSWORD)


@pytest.fixture
def signed_in(auth_api: AuthApi, primary_account: tuple[str, str]) -> Session:
    """A fresh session of its own for each test, so tests never share tokens."""
    response = auth_api.login(*primary_account)
    assert response.status == 200, f"precondition: login answered HTTP {response.status}"
    session = session_from(response)
    assert session.access_token and session.refresh_token, "precondition: login gave no tokens"
    return session


def assert_fields(data: Any, expected: dict[str, type | tuple[type, ...]], where: str) -> None:
    """Every documented field is present with the documented type."""
    assert isinstance(data, dict), f"{where}: expected an object, got {type(data).__name__}"
    missing = [k for k in expected if k not in data]
    assert not missing, f"{where}: missing documented field(s) {missing}"
    wrong = {
        k: type(data[k]).__name__
        for k, kind in expected.items()
        if data[k] is not None and not isinstance(data[k], kind)
    }
    assert not wrong, f"{where}: field type differs from the contract {wrong}"

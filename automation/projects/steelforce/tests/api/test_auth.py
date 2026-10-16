"""Authentication API contract, as the mobile app depends on it.

Source: docs/feature/authentication/README-endpoints.md and the app's
auth_remote_data_source.dart / auth_interceptor.dart. Each test is linked from
the workbook's Automation ID (Automation_Mapping sheet).
"""

import pytest

from steelforce.api.auth import AuthApi, Session, session_from
from steelforce.tests.api.conftest import assert_fields

# ── TC-AUTH-002 · Successful login ────────────────────────────────────────


def test_login_returns_a_usable_token_pair(auth_api: AuthApi, primary_account) -> None:
    response = auth_api.login(*primary_account)
    assert response.status == 200, f"login answered HTTP {response.status}"
    assert_fields(
        response.data,
        {
            "accessToken": str,
            "refreshToken": str,
            "tokenType": str,
            "expiresIn": int,
            "passwordChangeRequired": bool,
        },
        "login data",
    )
    assert response.data["tokenType"].lower() == "bearer"
    assert response.data["expiresIn"] > 0
    assert response.data["accessToken"] and response.data["refreshToken"]


def test_current_user_matches_the_contract(auth_api: AuthApi, signed_in: Session) -> None:
    response = auth_api.current_user(signed_in.access_token)
    assert response.status == 200, f"/auth/me answered HTTP {response.status}"
    assert_fields(
        response.data,
        {"id": str, "englishName": str, "empCode": str, "passwordChangeRequired": bool},
        "/auth/me data",
    )


# ── TC-PRO-001 · Profile loads ────────────────────────────────────────────


def test_my_profile_matches_the_contract(auth_api: AuthApi, signed_in: Session) -> None:
    response = auth_api.my_profile(signed_in.access_token)
    assert response.status == 200, f"/mobile/auth/profile answered HTTP {response.status}"
    assert_fields(
        response.data,
        {"id": str, "employeeCode": str, "fullName": str, "role": str},
        "/mobile/auth/profile data",
    )


# ── TC-SES-002 · Token refresh rotates ────────────────────────────────────


def test_refresh_rotates_both_tokens_and_the_new_access_token_works(
    auth_api: AuthApi, signed_in: Session
) -> None:
    response = auth_api.refresh(signed_in.refresh_token)
    assert response.status == 200, f"refresh answered HTTP {response.status}"
    rotated = session_from(response)
    assert rotated.access_token and rotated.refresh_token, "refresh returned no token pair"
    assert rotated.refresh_token != signed_in.refresh_token, "refresh token was not rotated"
    me = auth_api.current_user(rotated.access_token)
    assert me.status == 200, f"/auth/me with the new access token answered HTTP {me.status}"


def test_a_rotated_refresh_token_cannot_be_used_again(
    auth_api: AuthApi, signed_in: Session
) -> None:
    first = auth_api.refresh(signed_in.refresh_token)
    assert first.status == 200, f"precondition: refresh answered HTTP {first.status}"
    reuse = auth_api.refresh(signed_in.refresh_token)
    assert reuse.status in {400, 401}, (
        f"re-using a rotated refresh token answered HTTP {reuse.status}; "
        "the contract says it must be refused"
    )


# ── TC-SES-004 · Invalid credentials end the session ─────────────────────


def test_refresh_with_an_unknown_token_is_refused(auth_api: AuthApi) -> None:
    response = auth_api.refresh("not-a-real-refresh-token")
    assert response.status in {400, 401}, f"unknown refresh token answered HTTP {response.status}"


def test_a_protected_route_without_a_token_is_401(auth_api: AuthApi) -> None:
    response = auth_api.current_user(None)
    assert response.status == 401, f"/auth/me without a token answered HTTP {response.status}"


# ── TC-SES-007 · Sign-out revokes the session ─────────────────────────────


def test_logout_revokes_the_session(auth_api: AuthApi, signed_in: Session) -> None:
    response = auth_api.logout(signed_in)
    assert response.status in {200, 204}, f"logout answered HTTP {response.status}"
    after = auth_api.refresh(signed_in.refresh_token)
    assert after.status in {400, 401}, (
        f"refresh after logout answered HTTP {after.status}; the session should be revoked"
    )


# ── TC-AUTH-004 · Wrong password ──────────────────────────────────────────


@pytest.mark.lockout
def test_a_wrong_password_is_refused_without_tokens(auth_api: AuthApi, lockout_account) -> None:
    phone, password = lockout_account
    response = auth_api.login(phone, password + "-wrong")
    assert response.status == 400, (
        f"wrong password answered HTTP {response.status}; the OAuth contract answers 400"
    )
    body = response.body if isinstance(response.body, dict) else {}
    assert "accessToken" not in str(body), "a refused login must not return tokens"

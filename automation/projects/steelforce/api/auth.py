"""SteelForce authentication endpoints, called exactly as the mobile app calls them.

Paths and bodies mirror ``lib/core/network/api/api_endpoints.dart`` and
``auth_remote_data_source.dart``; the contract is
``docs/feature/authentication/README-endpoints.md``. Paths are relative to the
environment's ``api_prefix`` (``/api/v1``).
"""

import re
from dataclasses import dataclass

from automation.api.client import ApiClient, ApiResponse

LOGIN = "/mobile/auth/login"
REFRESH = "/mobile/auth/refresh-token"
CURRENT_USER = "/auth/me"
MY_PROFILE = "/mobile/auth/profile"
# The app still calls the web logout route (README-endpoints.md §3 flags it).
LOGOUT = "/auth/logout"

COUNTRY_CODE = "855"
# A fixed id so every automation session is easy to recognise in the
# sessions list and never collides with a rep's real handset.
AUTOMATION_DEVICE_ID = "qa-automation-steelforce"


def to_international(phone: str) -> str:
    """``012 000 111`` / ``12000111`` / ``+85512000111`` → ``+85512000111``.

    Mirrors the app's phone field, which always sends ``+855`` + the national
    number (``phone_number_field.dart``).
    """
    digits = re.sub(r"\D", "", phone)
    if phone.strip().startswith("+"):
        return f"+{digits}"
    if digits.startswith(COUNTRY_CODE) and len(digits) > 10:
        return f"+{digits}"
    return f"+{COUNTRY_CODE}{digits.removeprefix('0')}"


def device_descriptor(app_version: str) -> dict[str, object]:
    return {
        "deviceId": AUTOMATION_DEVICE_ID,
        "deviceName": "QA automation",
        "platform": "Automation",
        "appVersion": app_version,
        "timeZone": "Asia/Phnom_Penh",
        "language": "en",
        "rememberDevice": False,
    }


@dataclass(frozen=True)
class Session:
    access_token: str
    refresh_token: str


class AuthApi:
    def __init__(self, client: ApiClient, app_version: str = "") -> None:
        self._client = client
        self._app_version = app_version

    def login(self, phone: str, password: str) -> ApiResponse:
        return self._client.post(
            LOGIN,
            json={
                "phoneNumber": to_international(phone),
                "password": password,
                "deviceId": AUTOMATION_DEVICE_ID,
                "device": device_descriptor(self._app_version),
            },
        )

    def current_user(self, access_token: str | None) -> ApiResponse:
        return self._client.get(CURRENT_USER, token=access_token)

    def my_profile(self, access_token: str) -> ApiResponse:
        return self._client.get(MY_PROFILE, token=access_token)

    def refresh(self, refresh_token: str) -> ApiResponse:
        return self._client.post(
            REFRESH, json={"refreshToken": refresh_token, "deviceId": AUTOMATION_DEVICE_ID}
        )

    def logout(self, session: Session) -> ApiResponse:
        return self._client.post(
            LOGOUT, json={"refreshToken": session.refresh_token}, token=session.access_token
        )


def session_from(response: ApiResponse) -> Session:
    data = response.data if isinstance(response.data, dict) else {}
    return Session(str(data.get("accessToken", "")), str(data.get("refreshToken", "")))

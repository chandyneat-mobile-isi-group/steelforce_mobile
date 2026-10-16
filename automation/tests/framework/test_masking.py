import pytest

from automation.core.masking import MASK, Masker, mask_phone

JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"


@pytest.mark.parametrize(
    "key",
    ["password", "newPassword", "refreshToken", "reset_token", "Authorization", "X-Api-Key", "otp"],
)
def test_sensitive_keys_are_masked_whatever_their_case_or_separators(key: str) -> None:
    assert Masker().mask({key: "value"}) == {key: MASK}


def test_nested_bodies_are_masked_and_the_input_is_untouched() -> None:
    body = {"user": {"accessToken": "abc", "name": "Rep"}, "items": [{"password": "p"}]}
    masked = Masker().mask(body)
    assert masked == {"user": {"accessToken": MASK, "name": "Rep"}, "items": [{"password": MASK}]}
    assert body["user"]["accessToken"] == "abc"


def test_a_jwt_under_an_innocent_key_is_still_masked() -> None:
    assert Masker().mask({"note": f"got {JWT} back"}) == {"note": f"got {MASK} back"}


def test_bearer_headers_in_free_text_are_masked() -> None:
    assert (
        Masker().mask_text("Authorization: Bearer abcdefghijkl") == f"Authorization: Bearer {MASK}"
    )


@pytest.mark.parametrize("phone", ["012345678", "012 345 678", "+855 12 345 678", "0961234567"])
def test_phone_numbers_keep_only_their_ends(phone: str) -> None:
    masked = Masker().mask_text(f"sms to {phone}")
    assert phone not in masked
    assert MASK in masked


def test_mask_phone_keeps_three_digits_each_side() -> None:
    assert mask_phone("012345678") == f"012{MASK}678"


def test_ordinary_text_and_numbers_are_left_alone() -> None:
    text = "TC-AUTH-002 took 412 ms, status 200, 36 cases"
    assert Masker().mask_text(text) == text


def test_projects_can_add_their_own_keys() -> None:
    assert Masker(["employeeCode"]).mask({"employeeCode": "E1"}) == {"employeeCode": MASK}
    assert Masker().mask({"employeeCode": "E1"}) == {"employeeCode": "E1"}

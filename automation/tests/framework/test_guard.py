from pathlib import Path

import pytest

from automation.core.config import load_environment
from automation.core.constants import PRODUCTION_CONSENT_ENV, PRODUCTION_CONSENT_VALUE
from automation.core.exceptions import EnvironmentGuardError
from automation.core.guard import ensure_environment_allowed, ensure_markers_allowed

CONSENT = {PRODUCTION_CONSENT_ENV: PRODUCTION_CONSENT_VALUE}


def test_an_unprotected_environment_needs_nothing(project_dir: Path) -> None:
    ensure_environment_allowed(load_environment(project_dir, "uat"), False, environ={})


@pytest.mark.parametrize(
    ("flag", "environ"),
    [(False, {}), (True, {}), (False, CONSENT), (True, {PRODUCTION_CONSENT_ENV: "yes"})],
)
def test_production_needs_both_the_flag_and_the_exact_consent(
    project_dir: Path, flag: bool, environ: dict[str, str]
) -> None:
    with pytest.raises(EnvironmentGuardError, match="protected"):
        ensure_environment_allowed(load_environment(project_dir, "production"), flag, environ)


def test_production_runs_with_flag_and_consent(project_dir: Path) -> None:
    ensure_environment_allowed(load_environment(project_dir, "production"), True, CONSENT)


@pytest.mark.parametrize("marker", ["destructive", "sms", "lockout"])
def test_risky_markers_are_refused_on_production_whatever_the_flags(
    project_dir: Path, marker: str
) -> None:
    with pytest.raises(EnvironmentGuardError, match=marker):
        ensure_markers_allowed(load_environment(project_dir, "production"), [marker, "smoke"])


def test_risky_markers_are_allowed_off_production(project_dir: Path) -> None:
    ensure_markers_allowed(load_environment(project_dir, "uat"), ["destructive"])

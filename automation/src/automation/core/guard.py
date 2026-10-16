"""Stops automation reaching a protected (production) environment by accident.

A protected environment needs two things at once: the ``--allow-protected``
flag on the command line **and** the consent sentence exported in
``AUTOMATION_ALLOW_PROTECTED``. Even then, tests carrying a safety marker
(destructive, sms, lockout) are refused there.
"""

import os
from collections.abc import Iterable, Mapping

from automation.core.config import EnvironmentConfig
from automation.core.constants import (
    PRODUCTION_CONSENT_ENV,
    PRODUCTION_CONSENT_VALUE,
    SafetyMarker,
)
from automation.core.exceptions import EnvironmentGuardError


def ensure_environment_allowed(
    environment: EnvironmentConfig,
    allow_protected_flag: bool,
    environ: Mapping[str, str] | None = None,
) -> None:
    if not environment.protected:
        return
    process = os.environ if environ is None else environ
    consented = process.get(PRODUCTION_CONSENT_ENV) == PRODUCTION_CONSENT_VALUE
    if allow_protected_flag and consented:
        return
    raise EnvironmentGuardError(
        f"Environment {environment.name!r} is protected. To run against it pass "
        f"--allow-protected and export {PRODUCTION_CONSENT_ENV}="
        f'"{PRODUCTION_CONSENT_VALUE}".'
    )


def ensure_markers_allowed(environment: EnvironmentConfig, markers: Iterable[str]) -> None:
    """Refuse safety-marked tests on a protected environment, whatever the flags say."""
    if not environment.protected:
        return
    risky = sorted(set(markers) & {m.value for m in SafetyMarker})
    if risky:
        raise EnvironmentGuardError(
            f"Tests marked {risky} can never run against protected environment "
            f"{environment.name!r}."
        )

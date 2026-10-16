"""Vocabulary shared by every layer: results, issue sources, safety markers."""

from enum import StrEnum


class ResultStatus(StrEnum):
    PASS = "Pass"
    FAIL = "Fail"
    BLOCKED = "Blocked"
    SKIPPED = "Skipped"
    NOT_RUN = "Not Run"


class IssueSource(StrEnum):
    MOBILE = "Mobile"
    BACKEND = "Backend"
    DATABASE = "Database"
    SAP = "SAP"
    NETWORK = "Network"
    TEST_DATA = "Test Data"
    ENVIRONMENT = "Environment"
    AUTOMATION = "Automation"
    UNKNOWN = "Unknown"


class Confidence(StrEnum):
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


class SafetyMarker(StrEnum):
    """Pytest markers for tests that are excluded unless asked for by name."""

    DESTRUCTIVE = "destructive"
    SMS = "sms"
    LOCKOUT = "lockout"


# The value an operator must export to run against a protected environment.
# Deliberately a sentence, so it cannot be set by accident or by habit.
PRODUCTION_CONSENT_ENV = "AUTOMATION_ALLOW_PROTECTED"
PRODUCTION_CONSENT_VALUE = "I understand this targets a protected environment"

PROJECT_ENV = "AUTOMATION_PROJECT"

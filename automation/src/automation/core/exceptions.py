"""Framework errors. Each carries a message safe to show a user: no secrets."""


class AutomationError(Exception):
    """Base for every error the framework raises on purpose."""


class ConfigError(AutomationError):
    """A project or environment configuration is missing or invalid."""


class WorkbookError(AutomationError):
    """The workbook cannot be read at all (missing file, sheet or column)."""


class EnvironmentGuardError(AutomationError):
    """The run targets a protected environment without the required consent."""

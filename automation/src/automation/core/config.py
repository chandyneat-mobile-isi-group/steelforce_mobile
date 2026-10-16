"""Project profiles, environments and secrets.

Layout of one project profile::

    projects/<name>/
        project.yaml              what the app is: workbook, columns, Flutter dir
        environments/<env>.yaml   non-secret settings per environment
        .env.<env>                secrets per environment (gitignored)
        .env.example              committed template with placeholders

Process environment variables override ``.env.<env>`` values, so CI injects
secrets without writing files. Unknown keys in YAML are rejected: a typo in a
config file fails loudly instead of being silently ignored.
"""

import json
import os
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml
from dotenv import dotenv_values
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from automation.core.constants import PROJECT_ENV
from automation.core.exceptions import ConfigError

AUTOMATION_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_PROJECTS_DIR = AUTOMATION_ROOT / "projects"
PROJECTS_DIR_ENV = "AUTOMATION_PROJECTS_DIR"


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class WorkbookSettings(_Strict):
    path: Path
    sheets: dict[str, str] = Field(default_factory=dict)
    columns: dict[str, dict[str, str]] = Field(default_factory=dict)
    # Field → list header in the dropdowns sheet holding its allowed values.
    allowed_values: dict[str, str] = Field(default_factory=dict)
    id_pattern: str = r"^[A-Z][A-Z0-9]*(-[A-Z0-9]+)+$"
    # Environment-column value for results that ran only on this machine
    # (unit/widget tests): they say nothing about a backend environment.
    local_environment_label: str = ""


class FlutterSettings(_Strict):
    project_dir: Path = Path(".")
    # Host-side driver for device tests (`flutter drive --driver`), relative to
    # project_dir.
    integration_driver: Path = Path("test_driver/integration_test.dart")
    # `--dart-define` name → secret name. Device tests get configuration this
    # way; the values come from Secrets and never touch a file.
    dart_defines: dict[str, str] = Field(default_factory=dict)
    device_timeout_s: float = Field(default=1800, gt=0)


class MaskingSettings(_Strict):
    extra_keys: list[str] = Field(default_factory=list)


class ProjectConfig(_Strict):
    name: str
    display_name: str
    app_root: Path
    default_environment: str
    workbook: WorkbookSettings
    flutter: FlutterSettings = FlutterSettings()
    masking: MaskingSettings = MaskingSettings()
    # Secret name → what it is for. Names only; values never live in YAML.
    secrets: dict[str, str] = Field(default_factory=dict)


class ApiSettings(_Strict):
    base_url_env: str
    api_prefix: str = ""
    connect_timeout_s: float = Field(15.0, gt=0)
    read_timeout_s: float = Field(20.0, gt=0)
    retries: int = Field(1, ge=0, le=5)
    # On 429, wait for Retry-After and retry once if it is at most this long.
    # A 429 was rejected unprocessed, so retrying is safe for any method.
    rate_limit_max_wait_s: float = Field(0.0, ge=0, le=300)


class EnvironmentFlutterSettings(_Strict):
    device: str | None = None


class EnvironmentConfig(_Strict):
    name: str
    description: str = ""
    protected: bool = False
    # How the workbook's Environment column names this environment.
    workbook_label: str = ""
    api: ApiSettings
    flutter: EnvironmentFlutterSettings = EnvironmentFlutterSettings()


class Secrets:
    """Secret values for one run. Never printed: ``repr`` lists names only."""

    def __init__(self, values: Mapping[str, str]) -> None:
        self._values = dict(values)

    def get(self, name: str) -> str | None:
        value = self._values.get(name)
        return value or None

    def require(self, name: str) -> str:
        value = self.get(name)
        if value is None:
            raise ConfigError(
                f"Secret {name!r} is not set. Add it to the environment's .env file "
                "or export it (names are listed under `secrets:` in project.yaml)."
            )
        return value

    def names(self) -> list[str]:
        return sorted(k for k, v in self._values.items() if v)

    def redact(self, text: str, replacement: str = "***") -> str:
        """Every exact secret value in ``text`` replaced — as written and as it
        appears inside JSON. Values shorter than 4 characters are left alone:
        they are flags, not secrets, and replacing them would shred the text."""
        for value in sorted(filter(None, self._values.values()), key=len, reverse=True):
            if len(value) < 4:
                continue
            for form in {value, json.dumps(value)[1:-1]}:
                text = text.replace(form, replacement)
        return text

    def __repr__(self) -> str:
        return f"Secrets(names={self.names()})"


@dataclass(frozen=True)
class RunContext:
    project: ProjectConfig
    environment: EnvironmentConfig
    secrets: Secrets
    project_dir: Path

    @property
    def app_root(self) -> Path:
        return (self.project_dir / self.project.app_root).resolve()

    @property
    def workbook_path(self) -> Path:
        return self.app_root / self.project.workbook.path

    @property
    def flutter_dir(self) -> Path:
        return self.app_root / self.project.flutter.project_dir

    @property
    def api_base_url(self) -> str:
        return self.secrets.require(self.environment.api.base_url_env).rstrip("/")


def projects_dir(override: Path | None = None) -> Path:
    if override is not None:
        return override
    from_env = os.environ.get(PROJECTS_DIR_ENV)
    return Path(from_env) if from_env else DEFAULT_PROJECTS_DIR


def discover_projects(root: Path) -> list[str]:
    if not root.is_dir():
        return []
    return sorted(p.parent.name for p in root.glob("*/project.yaml"))


def resolve_project_name(root: Path, requested: str | None) -> str:
    """Explicit flag, then ``AUTOMATION_PROJECT``, then the only project present."""
    available = discover_projects(root)
    name = requested or os.environ.get(PROJECT_ENV)
    if name:
        if name not in available:
            raise ConfigError(f"Unknown project {name!r}. Available: {available or 'none'}.")
        return name
    if len(available) == 1:
        return available[0]
    raise ConfigError(
        f"Choose a project with --project or {PROJECT_ENV}. Available: {available or 'none'}."
    )


def _read_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ConfigError(f"Missing config file: {path}")
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        raise ConfigError(f"{path} is not valid YAML: {error}") from error
    if not isinstance(data, dict):
        raise ConfigError(f"{path} must contain a mapping at the top level.")
    return data


def _parse[T: BaseModel](model: type[T], path: Path) -> T:
    try:
        return model.model_validate(_read_yaml(path))
    except ValidationError as error:
        problems = "; ".join(
            f"{'.'.join(str(p) for p in e['loc']) or '<root>'}: {e['msg']}" for e in error.errors()
        )
        raise ConfigError(f"{path.name} is invalid — {problems}") from error


def load_project(project_dir: Path) -> ProjectConfig:
    project = _parse(ProjectConfig, project_dir / "project.yaml")
    if project.name != project_dir.name:
        raise ConfigError(
            f"project.yaml name {project.name!r} must match its folder {project_dir.name!r}."
        )
    return project


def available_environments(project_dir: Path) -> list[str]:
    return sorted(p.stem for p in (project_dir / "environments").glob("*.yaml"))


def load_environment(project_dir: Path, name: str) -> EnvironmentConfig:
    path = project_dir / "environments" / f"{name}.yaml"
    if not path.is_file():
        raise ConfigError(
            f"Unknown environment {name!r}. Available: {available_environments(project_dir)}."
        )
    environment = _parse(EnvironmentConfig, path)
    if environment.name != name:
        raise ConfigError(f"{path.name} declares name {environment.name!r}; expected {name!r}.")
    return environment


def _dotenv(path: Path) -> dict[str, str]:
    return {k: v for k, v in dotenv_values(path).items() if v is not None} if path.is_file() else {}


def load_secrets(
    project_dir: Path,
    environment: str,
    declared_names: Iterable[str] = (),
    environ: Mapping[str, str] | None = None,
) -> Secrets:
    """``.env.<environment>`` values, overridden by process variables of the same name.

    Only names declared in ``project.yaml`` (``secrets:``) or present in the env
    file are read from the process, so CI can inject secrets without a file but
    unrelated variables (PATH, HOME …) never become part of the run.
    """
    file_values = _dotenv(project_dir / f".env.{environment}")
    declared = file_values.keys() | set(declared_names)
    process = os.environ if environ is None else environ
    overrides = {k: process[k] for k in declared if process.get(k)}
    return Secrets({**file_values, **overrides})


def load_context(
    project: str | None = None,
    environment: str | None = None,
    root: Path | None = None,
    environ: Mapping[str, str] | None = None,
) -> RunContext:
    base = projects_dir(root)
    project_dir = base / resolve_project_name(base, project)
    project_config = load_project(project_dir)
    env_name = environment or project_config.default_environment
    return RunContext(
        project=project_config,
        environment=load_environment(project_dir, env_name),
        secrets=load_secrets(project_dir, env_name, project_config.secrets, environ),
        project_dir=project_dir,
    )

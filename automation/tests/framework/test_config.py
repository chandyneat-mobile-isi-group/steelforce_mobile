from pathlib import Path

import pytest

from automation.core.config import (
    DEFAULT_PROJECTS_DIR,
    Secrets,
    discover_projects,
    load_context,
    load_environment,
    load_project,
    load_secrets,
    resolve_project_name,
)
from automation.core.exceptions import ConfigError


def test_discovers_projects_by_their_project_yaml(projects_root: Path) -> None:
    (projects_root / "not-a-project").mkdir()
    assert discover_projects(projects_root) == ["demo"]


def test_the_only_project_is_chosen_when_none_is_named(projects_root: Path) -> None:
    assert resolve_project_name(projects_root, None) == "demo"


def test_an_unknown_project_is_refused_with_the_available_ones(projects_root: Path) -> None:
    with pytest.raises(ConfigError, match=r"Unknown project 'other'.*demo"):
        resolve_project_name(projects_root, "other")


def test_two_projects_require_a_choice(projects_root: Path) -> None:
    second = projects_root / "second"
    second.mkdir()
    (second / "project.yaml").write_text("name: second\n", encoding="utf-8")
    with pytest.raises(ConfigError, match="Choose a project"):
        resolve_project_name(projects_root, None)


def test_project_paths_resolve_from_app_root(projects_root: Path, project_dir: Path) -> None:
    ctx = load_context(root=projects_root, environ={})
    assert ctx.app_root == projects_root.parent.resolve()
    assert ctx.workbook_path == projects_root.parent.resolve() / "qa" / "cases.xlsx"
    assert ctx.environment.name == "uat"


def test_a_typo_in_project_yaml_fails_loudly(project_dir: Path) -> None:
    path = project_dir / "project.yaml"
    path.write_text(path.read_text() + "workbok: oops\n", encoding="utf-8")
    with pytest.raises(ConfigError, match="workbok"):
        load_project(project_dir)


def test_project_name_must_match_its_folder(project_dir: Path) -> None:
    path = project_dir / "project.yaml"
    path.write_text(path.read_text().replace("name: demo", "name: other"), encoding="utf-8")
    with pytest.raises(ConfigError, match="must match its folder"):
        load_project(project_dir)


def test_unknown_environment_lists_the_available_ones(project_dir: Path) -> None:
    with pytest.raises(ConfigError, match=r"Unknown environment 'qa'.*production.*uat"):
        load_environment(project_dir, "qa")


def test_invalid_timeout_is_rejected(project_dir: Path) -> None:
    path = project_dir / "environments" / "uat.yaml"
    path.write_text(path.read_text() + "  read_timeout_s: 0\n", encoding="utf-8")
    with pytest.raises(ConfigError, match="read_timeout_s"):
        load_environment(project_dir, "uat")


def test_secrets_come_from_the_environment_file(project_dir: Path) -> None:
    (project_dir / ".env.uat").write_text("DEMO_API_BASE_URL=https://uat.example\n")
    secrets = load_secrets(project_dir, "uat", environ={})
    assert secrets.require("DEMO_API_BASE_URL") == "https://uat.example"


def test_process_values_override_the_file_for_declared_names(project_dir: Path) -> None:
    (project_dir / ".env.uat").write_text("DEMO_API_BASE_URL=https://file.example\n")
    secrets = load_secrets(
        project_dir,
        "uat",
        declared_names=["DEMO_API_BASE_URL", "DEMO_PASSWORD"],
        environ={"DEMO_API_BASE_URL": "https://ci.example", "DEMO_PASSWORD": "x"},
    )
    assert secrets.get("DEMO_API_BASE_URL") == "https://ci.example"
    assert secrets.get("DEMO_PASSWORD") == "x"


def test_undeclared_process_variables_are_never_read(project_dir: Path) -> None:
    secrets = load_secrets(project_dir, "uat", environ={"PATH": "/usr/bin", "HOME": "/x"})
    assert secrets.names() == []


def test_a_missing_secret_names_itself_but_no_value(project_dir: Path) -> None:
    secrets = load_secrets(project_dir, "uat", environ={})
    with pytest.raises(ConfigError, match="DEMO_PASSWORD"):
        secrets.require("DEMO_PASSWORD")


def test_secrets_repr_never_shows_values(project_dir: Path) -> None:
    secrets = load_secrets(
        project_dir, "uat", declared_names=["DEMO_PASSWORD"], environ={"DEMO_PASSWORD": "hunter2"}
    )
    assert "hunter2" not in repr(secrets)
    assert "DEMO_PASSWORD" in repr(secrets)


def test_api_base_url_drops_a_trailing_slash(projects_root: Path, project_dir: Path) -> None:
    (project_dir / ".env.uat").write_text("DEMO_API_BASE_URL=https://uat.example/\n")
    ctx = load_context(root=projects_root, environ={})
    assert ctx.api_base_url == "https://uat.example"


def test_the_shipped_steelforce_profile_loads() -> None:
    ctx = load_context("steelforce", "uat", DEFAULT_PROJECTS_DIR, environ={})
    assert ctx.project.workbook.columns["test_cases"]["id"] == "TC ID"
    assert ctx.environment.protected is False
    assert load_context(
        "steelforce", "production", DEFAULT_PROJECTS_DIR, environ={}
    ).environment.protected


def test_secrets_redact_exact_values_but_not_short_flags() -> None:
    secrets = Secrets({"PW": 'pa"ss-1234', "FLAG": "1"})
    assert secrets.redact('raw pa"ss-1234 json "pa\\"ss-1234" 1') == 'raw *** json "***" 1'

"""The whole dashboard script runs headless on the sample warehouse without an exception."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

from .conftest import ANALYTICS_DIR

APP = ANALYTICS_DIR / "dashboard" / "app.py"
APP_TIMEOUT_S = 60  # first run imports altair/pandas; generous for CI runners


@pytest.fixture
def warehouse_copy(built_warehouse: Path, tmp_path: Path) -> Path:
    """A copy of the built warehouse (plus its WAL, replayed on open).

    The dashboard opens the file read-only; dbt-duckdb still holds a read-write connection
    to the original in this process, and DuckDB refuses mixed configurations on one file.
    """
    target = tmp_path / "dash.duckdb"
    shutil.copy(built_warehouse, target)
    wal = built_warehouse.with_name(built_warehouse.name + ".wal")
    if wal.exists():
        shutil.copy(wal, target.with_name(target.name + ".wal"))
    return target


def test_dashboard_renders(warehouse_copy: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TRIAD_DUCKDB_PATH", str(warehouse_copy))
    app = AppTest.from_file(str(APP), default_timeout=APP_TIMEOUT_S).run()

    assert not app.exception, [e.message for e in app.exception]
    headers = [h.value for h in app.header]
    for question in (
        "Where do runs fail?",
        "Which floor is hard?",
        "Who carries and who dies?",
        "Do abilities matter?",
        "Findings",
    ):
        assert question in headers
    assert app.selectbox[0].value.startswith("env:")  # the env var wins over the defaults
    assert [m.label for m in app.metric][:2] == ["Missions completed", "Battles"]

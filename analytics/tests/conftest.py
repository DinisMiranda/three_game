"""Shared fixtures: a warehouse built from the committed sample with the real dbt project."""

from __future__ import annotations

import json
import os
from collections.abc import Iterator
from pathlib import Path

import duckdb
import pytest
from dbt.cli.main import dbtRunner

from triad_analytics.ingest import ingest

ANALYTICS_DIR = Path(__file__).resolve().parents[1]
DBT_DIR = ANALYTICS_DIR / "dbt"
SAMPLE_FILE = ANALYTICS_DIR / "data" / "sample" / "greedy_seed1.jsonl"


@pytest.fixture(scope="session")
def sample_events() -> list[dict]:
    """The sample JSONL parsed with the standard library: the independent reference."""
    with SAMPLE_FILE.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


@pytest.fixture(scope="session")
def built_warehouse(tmp_path_factory: pytest.TempPathFactory) -> Iterator[Path]:
    """Ingest the sample into a fresh DuckDB file and run `dbt build` (models + tests) on it."""
    work = tmp_path_factory.mktemp("warehouse")
    db_path = work / "sample.duckdb"
    ingest([str(SAMPLE_FILE)], db_path)

    previous = os.environ.get("TRIAD_DUCKDB_PATH")
    os.environ["TRIAD_DUCKDB_PATH"] = str(db_path)
    try:
        result = dbtRunner().invoke(
            [
                "build",
                "--project-dir",
                str(DBT_DIR),
                "--profiles-dir",
                str(DBT_DIR),
                "--target-path",
                str(work / "target"),
                "--log-path",
                str(work / "logs"),
                "--quiet",
            ]
        )
    finally:
        if previous is None:
            os.environ.pop("TRIAD_DUCKDB_PATH", None)
        else:
            os.environ["TRIAD_DUCKDB_PATH"] = previous

    assert result.success, f"dbt build failed: {result.exception}"
    yield db_path


@pytest.fixture
def warehouse(built_warehouse: Path) -> Iterator[duckdb.DuckDBPyConnection]:
    """Connection to the built sample warehouse.

    Not read_only: dbt-duckdb keeps its in-process connection open, and DuckDB refuses a
    second connection to the same file with a different configuration.
    """
    with duckdb.connect(str(built_warehouse)) as con:
        yield con

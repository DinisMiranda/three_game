"""Ingest is idempotent by event_id and records lineage columns."""

from __future__ import annotations

from pathlib import Path

import duckdb
import pytest

from triad_analytics.ingest import ingest

from .conftest import SAMPLE_FILE

FIRST_N_LINES = 50  # a small slice keeps these tests fast


def _write_slice(path: Path, n_lines: int) -> Path:
    with SAMPLE_FILE.open(encoding="utf-8") as src:
        path.write_text("".join(next(src) for _ in range(n_lines)), encoding="utf-8")
    return path


def test_rerun_does_not_duplicate(tmp_path: Path, sample_events: list[dict]) -> None:
    db = tmp_path / "w.duckdb"
    first = ingest([str(SAMPLE_FILE)], db)
    second = ingest([str(SAMPLE_FILE)], db)

    assert first.rows_inserted == len(sample_events)
    assert second.rows_read == len(sample_events)
    assert second.rows_inserted == 0
    assert second.rows_total == len(sample_events)


def test_same_events_in_two_files_load_once(tmp_path: Path) -> None:
    a = _write_slice(tmp_path / "a.jsonl", FIRST_N_LINES)
    b = _write_slice(tmp_path / "b.jsonl", FIRST_N_LINES)
    result = ingest([str(a), str(b)], tmp_path / "w.duckdb")

    assert result.rows_read == 2 * FIRST_N_LINES
    assert result.rows_inserted == FIRST_N_LINES


def test_lineage_columns_and_json_payload(tmp_path: Path) -> None:
    db = tmp_path / "w.duckdb"
    ingest([str(_write_slice(tmp_path / "a.jsonl", FIRST_N_LINES))], db)
    with duckdb.connect(str(db), read_only=True) as con:
        missing, payload_type = con.execute(
            "select count_if(_source_file is null or _loaded_at is null), "
            "any_value(typeof(payload)) from raw.events"
        ).fetchone()
        files = con.execute("select distinct _source_file from raw.events").fetchall()

    assert missing == 0
    assert payload_type == "JSON"
    assert [Path(f).name for (f,) in files] == ["a.jsonl"]


def test_no_matching_files_is_an_error(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        ingest([str(tmp_path / "nothing_*.jsonl")], tmp_path / "w.duckdb")

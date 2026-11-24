"""Load telemetry JSONL files into ``raw.events`` in a DuckDB warehouse.

The raw layer is append-only and idempotent: an event whose ``event_id`` is
already loaded is skipped, so re-running the loader (or re-uploading a file)
never duplicates rows. The envelope is read with an explicit column list (the
contract in ``docs/analytics/event-schema.md``); ``payload`` stays JSON and is
unnested per event type by the dbt staging models.
"""

from __future__ import annotations

import argparse
import glob
from dataclasses import dataclass
from pathlib import Path

import duckdb

# Envelope columns, in contract order. Timestamps stay strings here; staging casts them.
ENVELOPE_COLUMNS: dict[str, str] = {
    "schema_version": "INTEGER",
    "event_id": "VARCHAR",
    "event_name": "VARCHAR",
    "event_seq": "BIGINT",
    "ts_utc": "VARCHAR",
    "session_id": "VARCHAR",
    "run_id": "VARCHAR",
    "battle_id": "VARCHAR",
    "source": "VARCHAR",
    "game_version": "VARCHAR",
    "platform": "VARCHAR",
    "payload": "JSON",
}

_COLUMN_DDL = ",\n    ".join(f"{name} {dtype}" for name, dtype in ENVELOPE_COLUMNS.items())

CREATE_RAW_EVENTS = f"""
create schema if not exists raw;
create table if not exists raw.events (
    {_COLUMN_DDL},
    _source_file VARCHAR NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL
);
"""

_COLUMN_LIST = ", ".join(ENVELOPE_COLUMNS)
_READ_JSON_COLUMNS = "{" + ", ".join(f"'{k}': '{v}'" for k, v in ENVELOPE_COLUMNS.items()) + "}"

# Anti-join on event_id against what is already loaded, and keep the first copy of an
# event_id that appears twice inside the same batch (e.g. the same file passed twice).
INSERT_NEW_EVENTS = f"""
insert into raw.events
with batch as (
    select {_COLUMN_LIST}, filename as _source_file
    from read_json(
        $files,
        format = 'newline_delimited',
        columns = {_READ_JSON_COLUMNS},
        filename = true
    )
),

deduped as (
    select *
    from batch
    qualify row_number() over (partition by event_id order by _source_file) = 1
)

select deduped.*, current_timestamp as _loaded_at
from deduped
anti join raw.events as loaded using (event_id)
"""


@dataclass(frozen=True)
class IngestResult:
    """Outcome of one ingest call."""

    files: int
    rows_read: int
    rows_inserted: int
    rows_total: int


def resolve_files(patterns: list[str]) -> list[str]:
    """Expand glob patterns into a sorted, de-duplicated list of existing files."""
    files = {str(Path(p).resolve()) for pattern in patterns for p in glob.glob(pattern)}
    return sorted(files)


def ingest(patterns: list[str], db_path: str | Path) -> IngestResult:
    """Load every JSONL file matching ``patterns`` into ``raw.events`` at ``db_path``."""
    files = resolve_files(patterns)
    if not files:
        raise FileNotFoundError(f"no files match {patterns}")

    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(db_path)) as con:
        con.execute(CREATE_RAW_EVENTS)
        rows_read = con.execute(
            "select count(*) from read_json($files, format = 'newline_delimited', "
            f"columns = {_READ_JSON_COLUMNS})",
            {"files": files},
        ).fetchone()[0]
        before = con.execute("select count(*) from raw.events").fetchone()[0]
        con.execute(INSERT_NEW_EVENTS, {"files": files})
        after = con.execute("select count(*) from raw.events").fetchone()[0]

    return IngestResult(len(files), rows_read, after - before, after)


def main(argv: list[str] | None = None) -> None:
    """CLI entry point: ``triad-ingest --input <glob> [--input <glob>] --db <path>``."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--input", action="append", required=True, help="JSONL file or glob (repeatable)"
    )
    parser.add_argument("--db", required=True, help="DuckDB warehouse file")
    args = parser.parse_args(argv)

    result = ingest(args.input, args.db)
    print(
        f"ingested {result.files} file(s): read {result.rows_read} rows, "
        f"inserted {result.rows_inserted}, raw.events now {result.rows_total}"
    )


if __name__ == "__main__":
    main()

"""The marts agree with counts computed straight from the JSONL in plain Python.

The `built_warehouse` fixture runs `dbt build`, so every dbt data test also has to pass.
"""

from __future__ import annotations

from collections import Counter

import duckdb


def _by_name(events: list[dict], name: str) -> list[dict]:
    return [e for e in events if e["event_name"] == name]


def test_battle_count(warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]) -> None:
    expected = len(_by_name(sample_events, "battle_start"))
    (actual,) = warehouse.execute("select count(*) from marts.fct_battles").fetchone()
    assert actual == expected


def test_wins_and_battles_per_floor(
    warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]
) -> None:
    floor_of = {
        e["battle_id"]: e["payload"]["floor"] for e in _by_name(sample_events, "battle_start")
    }
    battles = Counter(floor_of.values())
    wins = Counter(
        floor_of[e["battle_id"]]
        for e in _by_name(sample_events, "battle_end")
        if e["payload"]["result"] == "win"
    )
    rows = warehouse.execute(
        "select floor, battles, wins, win_rate from marts.mart_floor_difficulty "
        "where policy = 'greedy' order by floor"
    ).fetchall()

    assert {floor: (n, w) for floor, n, w, _ in rows} == {
        floor: (battles[floor], wins[floor]) for floor in battles
    }
    for floor, n, w, win_rate in rows:
        assert win_rate == w / n, floor


def test_total_damage_per_hero(
    warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]
) -> None:
    expected: Counter[str] = Counter()
    for e in _by_name(sample_events, "action"):
        if e["payload"]["actor_side"] == "party":
            expected[e["payload"]["actor_id"]] += e["payload"]["damage"]
    rows = warehouse.execute(
        "select hero_id, total_damage from marts.mart_hero_performance where policy = 'greedy'"
    ).fetchall()
    assert dict(rows) == dict(expected)


def test_one_action_row_per_hit(
    warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]
) -> None:
    (actual,) = warehouse.execute("select count(*) from marts.fct_actions").fetchone()
    assert actual == len(_by_name(sample_events, "action"))


def test_deaths_per_hero(warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]) -> None:
    expected = Counter(
        e["payload"]["battler_id"]
        for e in _by_name(sample_events, "battler_down")
        if e["payload"]["side"] == "party"
    )
    rows = warehouse.execute(
        "select hero_id, deaths from marts.mart_hero_performance where policy = 'greedy'"
    ).fetchall()
    assert {hero: d for hero, d in rows if d} == dict(expected)


def test_mission_results(warehouse: duckdb.DuckDBPyConnection, sample_events: list[dict]) -> None:
    expected = Counter(e["payload"]["result"] for e in _by_name(sample_events, "mission_end"))
    rows = warehouse.execute(
        "select mission_result, count(*) from marts.fct_mission_funnel group by 1"
    ).fetchall()
    assert dict(rows) == dict(expected)

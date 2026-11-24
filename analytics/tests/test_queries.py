"""Dashboard queries on the sample warehouse: shapes, keys, and values matching the marts."""

from __future__ import annotations

import duckdb
import pandas as pd
import pytest

from triad_analytics import queries as q


def _scalar(con: duckdb.DuckDBPyConnection, sql: str):
    return con.execute(sql).fetchone()[0]


def test_kpis(warehouse: duckdb.DuckDBPyConnection) -> None:
    kpi = q.kpis(warehouse)
    assert list(kpi["policy"]) == ["greedy"]  # the sample is greedy only
    row = kpi.iloc[0]
    assert row["runs"] == _scalar(warehouse, "select count(*) from marts.fct_mission_funnel")
    assert row["battles"] == _scalar(warehouse, "select count(*) from marts.fct_battles")
    assert row["completion_rate"] == row["completed"] / row["runs"]
    assert row["mean_turns"] == pytest.approx(
        _scalar(warehouse, "select avg(turns) from marts.fct_battles")
    )
    assert 0 <= row["party_crit_rate"] <= 1


def test_mission_funnel(warehouse: duckdb.DuckDBPyConnection) -> None:
    funnel = q.mission_funnel(warehouse)
    assert list(funnel["step"]) == list(q.FUNNEL_STEPS.values())
    assert funnel["runs"].is_monotonic_decreasing  # non-increasing: no step gains runs
    assert funnel.iloc[0]["share_of_started"] == 1
    completed = _scalar(
        warehouse,
        "select count(*) from marts.fct_mission_funnel where mission_result = 'completed'",
    )
    assert funnel.iloc[-1]["runs"] == completed


def test_floor_difficulty_matches_mart(warehouse: duckdb.DuckDBPyConnection) -> None:
    floors = q.floor_difficulty(warehouse)
    mart = warehouse.execute(
        "select policy, floor, battles, win_rate from marts.mart_floor_difficulty "
        "order by policy, floor"
    ).df()
    pd.testing.assert_frame_equal(
        floors[["policy", "floor", "battles", "win_rate"]], mart, check_dtype=False
    )


def test_hero_performance(warehouse: duckdb.DuckDBPyConnection) -> None:
    heroes = q.hero_performance(warehouse)
    assert not heroes.duplicated(["policy", "hero_id"]).any()
    assert heroes["hero_name"].notna().all() and heroes["role_label"].notna().all()
    assert heroes.groupby("policy")["damage_share"].sum().to_numpy() == pytest.approx(1)


def test_ability_usage(warehouse: duckdb.DuckDBPyConnection) -> None:
    usage = q.ability_usage(warehouse)
    assert not usage.duplicated(["policy", "ability_id"]).any()
    assert usage.groupby("policy")["usage_share"].sum().to_numpy() == pytest.approx(1)
    assert usage["uses"].sum() == _scalar(
        warehouse,
        "select count(*) from marts.fct_actions where actor_side = 'party' and hit_index = 0",
    )
    assert usage["total_damage"].sum() == _scalar(
        warehouse, "select sum(damage) from marts.fct_actions where actor_side = 'party'"
    )


def test_findings_name_the_most_dying_hero(warehouse: duckdb.DuckDBPyConnection) -> None:
    found = q.findings(warehouse)
    assert list(found.columns) == ["topic", "finding"]
    heroes = q.hero_performance(warehouse)
    top = heroes.sort_values("death_rate_per_battle", ascending=False).iloc[0]
    (death_line,) = found.loc[found["topic"] == "Who dies?", "finding"]
    assert death_line.startswith(f"{top['hero_name']} dies in")
    # The sample has no attack_only runs, so there is no ability comparison to make.
    assert "Do abilities matter?" not in set(found["topic"])


def test_findings_compare_policies_when_both_exist() -> None:
    kpi = pd.DataFrame(
        {
            "policy": ["attack_only", "greedy"],
            "completion_rate": [0.90, 0.99],
            "mean_turns": [14.0, 13.0],
            "party_crit_rate": [0.149, 0.152],
        }
    )
    floors = pd.DataFrame(
        {"policy": ["greedy"], "floor": [2], "win_rate": [1.0], "mean_party_hp_lost_pct": [0.5]}
    )
    heroes = pd.DataFrame(columns=["policy", "hero_id", "hero_name", "damage_share"])
    found = q.findings_from(kpi, floors, heroes).set_index("topic")["finding"]
    assert "99.0% vs 90.0% (+9.0 pp)" in found["Do abilities matter?"]
    assert found["Which floor is hard?"] == "No policy lost a battle on any floor."
    assert "14.9% to 15.2%" in found["Crits"]

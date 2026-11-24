"""Dashboard queries over the dbt marts.

Each query function takes an open DuckDB connection and returns a pandas DataFrame with
every policy in the warehouse; the dashboard filters by policy itself. ``findings_from``
is pure (DataFrames in, sentences out), so the "Findings" panel is computed from the data
and changes when Phase 6 rebalances the game.
"""

from __future__ import annotations

import duckdb
import pandas as pd

# BattleManager.CRIT_CHANCE in scripts/battle/battle_manager.gd: the designed crit rate.
DESIGNED_CRIT_RATE = 0.15

# fct_mission_funnel column -> funnel step label, in funnel order.
FUNNEL_STEPS: dict[str, str] = {
    "started": "started",
    "reached_floor_1": "floor 1",
    "reached_floor_2": "floor 2",
    "reached_floor_3": "floor 3",
    "completed": "completed",
}


def _df(con: duckdb.DuckDBPyConnection, sql: str) -> pd.DataFrame:
    return con.execute(sql).df()


def kpis(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """One row per policy: runs, completion rate, battles, mean turns, party crit rate."""
    return _df(
        con,
        """
        with runs as (
            select
                policy,
                count(*) as runs,
                cast(count_if(mission_result = 'completed') as bigint) as completed
            from marts.fct_mission_funnel
            group by policy
        ),

        battles as (
            select policy, count(*) as battles, avg(turns) as mean_turns
            from marts.fct_battles
            group by policy
        ),

        crits as (
            select
                policy,
                count_if(is_damage_attempt and is_crit) / count_if(is_damage_attempt)
                    as party_crit_rate
            from marts.fct_actions
            where actor_side = 'party'
            group by policy
        )

        select
            runs.policy,
            runs.runs,
            runs.completed,
            runs.completed / runs.runs as completion_rate,
            battles.battles,
            battles.mean_turns,
            crits.party_crit_rate
        from runs
        left join battles on runs.policy = battles.policy
        left join crits on runs.policy = crits.policy
        order by runs.policy
        """,
    )


def mission_funnel(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """Long format, one row per policy x funnel step: runs and share of started runs."""
    wide = _df(
        con,
        """
        select
            policy,
            count(*) as started,
            cast(count_if(reached_floor_1) as bigint) as reached_floor_1,
            cast(count_if(reached_floor_2) as bigint) as reached_floor_2,
            cast(count_if(reached_floor_3) as bigint) as reached_floor_3,
            cast(count_if(mission_result = 'completed') as bigint) as completed
        from marts.fct_mission_funnel
        group by policy
        order by policy
        """,
    )
    long = wide.melt(id_vars="policy", var_name="column", value_name="runs")
    long["step"] = long["column"].map(FUNNEL_STEPS)
    long["step_order"] = long["column"].map({c: i for i, c in enumerate(FUNNEL_STEPS)})
    started = long.loc[long["column"] == "started"].set_index("policy")["runs"]
    long["share_of_started"] = long["runs"] / long["policy"].map(started)
    return (
        long.drop(columns="column")
        .sort_values(["policy", "step_order"])
        .reset_index(drop=True)[["policy", "step_order", "step", "runs", "share_of_started"]]
    )


def floor_difficulty(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """mart_floor_difficulty as-is: one row per policy x floor."""
    return _df(
        con,
        """
        select
            policy, floor, battles,
            cast(wins as bigint) as wins,
            cast(losses as bigint) as losses,
            win_rate, mean_turns, mean_party_hp_lost_pct
        from marts.mart_floor_difficulty
        order by policy, floor
        """,
    )


def hero_performance(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """mart_hero_performance with display names and roles from dim_battlers."""
    return _df(
        con,
        """
        select
            heroes.policy,
            heroes.hero_id,
            coalesce(battlers.display_name, heroes.hero_id) as hero_name,
            battlers.role_label,
            heroes.battles_played,
            cast(heroes.total_damage as bigint) as total_damage,
            heroes.damage_share,
            heroes.damage_per_action,
            heroes.crit_rate,
            cast(heroes.deaths as bigint) as deaths,
            heroes.death_rate_per_battle
        from marts.mart_hero_performance as heroes
        left join marts.dim_battlers as battlers on heroes.hero_id = battlers.battler_key
        order by heroes.policy, heroes.hero_id
        """,
    )


def ability_usage(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """One row per policy x party ability: uses, usage share, damage and energy per use."""
    return _df(
        con,
        """
        with by_ability as (
            select
                policy,
                ability_id,
                cast(count_if(hit_index = 0) as bigint) as uses,  -- one decision per action_seq
                cast(sum(damage) as bigint) as total_damage,
                sum(energy_cost) / count_if(hit_index = 0) as energy_per_use
            from marts.fct_actions
            where actor_side = 'party'
            group by policy, ability_id
        )

        select
            policy,
            ability_id,
            uses,
            uses / sum(uses) over (partition by policy) as usage_share,
            total_damage,
            total_damage / uses as damage_per_use,
            energy_per_use
        from by_ability
        order by policy, uses desc
        """,
    )


def _pct(x: float) -> str:
    return f"{100 * x:.1f}%"


def findings_from(kpi: pd.DataFrame, floors: pd.DataFrame, heroes: pd.DataFrame) -> pd.DataFrame:
    """Plain-language findings computed from the query frames. Columns: topic, finding."""
    rows: list[tuple[str, str]] = []

    # Hardest floor: the lowest win rate per policy, grouped when policies agree.
    if not floors.empty:
        hardest = floors.loc[floors.groupby("policy")["win_rate"].idxmin()]
        for floor, grp in hardest.groupby("floor"):
            if (grp["win_rate"] >= 1).all():
                continue
            wins = ", ".join(
                f"{p} {_pct(w)}" for p, w in zip(grp["policy"], grp["win_rate"], strict=True)
            )
            hp = ", ".join(_pct(h) for h in grp["mean_party_hp_lost_pct"])
            rows.append(
                (
                    "Which floor is hard?",
                    f"Floor {floor} has the lowest win rate ({wins}); parties lose {hp} "
                    "of their HP there.",
                )
            )
        if not rows:
            rows.append(("Which floor is hard?", "No policy lost a battle on any floor."))

    # Who dies: death rate pooled over policies, top hero against the runner-up.
    if heroes["hero_id"].nunique() >= 2:
        pooled = heroes.groupby("hero_name")[["deaths", "battles_played"]].sum()
        pooled["rate"] = pooled["deaths"] / pooled["battles_played"]
        top = pooled.sort_values("rate", ascending=False)
        (first, r1), (second, r2) = top["rate"].iloc[:2].items()
        ratio = f" ({r1 / r2:.1f}x)" if r2 > 0 else ""
        rows.append(
            (
                "Who dies?",
                f"{first} dies in {_pct(r1)} of battles (all policies pooled); the "
                f"next-highest hero, {second}, in {_pct(r2)}{ratio}.",
            )
        )

    # Who carries: the top damage share per policy, grouped by hero.
    if not heroes.empty:
        carry = heroes.loc[heroes.groupby("policy")["damage_share"].idxmax()]
        for hero, grp in carry.groupby("hero_name"):
            shares = ", ".join(
                f"{p} {_pct(s)}" for p, s in zip(grp["policy"], grp["damage_share"], strict=True)
            )
            rows.append(("Who carries?", f"{hero} has the highest damage share ({shares})."))

    # Do abilities matter: greedy (uses kits) against attack_only (basic attacks only).
    by_policy = kpi.set_index("policy")
    if {"greedy", "attack_only"} <= set(by_policy.index):
        g, a = by_policy.loc["greedy"], by_policy.loc["attack_only"]
        delta_pp = 100 * (g["completion_rate"] - a["completion_rate"])
        rows.append(
            (
                "Do abilities matter?",
                f"Using abilities (greedy) vs. basic attacks only (attack_only): missions "
                f"completed {_pct(g['completion_rate'])} vs {_pct(a['completion_rate'])} "
                f"({delta_pp:+.1f} pp), mean turns per battle {g['mean_turns']:.1f} vs "
                f"{a['mean_turns']:.1f}.",
            )
        )

    # Crit: observed party crit rate against the designed value.
    if not kpi.empty:
        low, high = kpi["party_crit_rate"].min(), kpi["party_crit_rate"].max()
        rows.append(
            (
                "Crits",
                f"Party crit rate is {_pct(low)} to {_pct(high)} across policies, against "
                f"the designed {_pct(DESIGNED_CRIT_RATE)}.",
            )
        )

    return pd.DataFrame(rows, columns=["topic", "finding"])


def findings(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """Findings for every policy in the warehouse."""
    return findings_from(kpis(con), floor_difficulty(con), hero_performance(con))

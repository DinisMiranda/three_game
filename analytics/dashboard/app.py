"""Triad Protocol balance dashboard.

Every view answers one balance question from the design brief and says what it shows.
Reads the dbt marts from a DuckDB warehouse; run with ``make dashboard`` from analytics/.
"""

from __future__ import annotations

import os
from pathlib import Path

import altair as alt
import duckdb
import pandas as pd
import streamlit as st

from triad_analytics import queries as q

ANALYTICS_DIR = Path(__file__).resolve().parents[1]
WAREHOUSES: dict[str, Path] = {
    "full: 500 sim runs per policy": ANALYTICS_DIR / "warehouse" / "triad.duckdb",
    "sample: 20 greedy runs": ANALYTICS_DIR / "warehouse" / "sample.duckdb",
}

# One colour per policy, the same in every chart. Cyan is the game's party colour.
POLICY_COLORS: dict[str, str] = {
    "greedy": "#00D9E6",
    "random": "#B48CFF",
    "attack_only": "#8A9BB0",
    "player": "#F2F5F8",
}
LOSS_COLOR = "#FF6B52"  # enemy / loss
ENERGY_COLOR = "#FFD23F"  # energy

st.set_page_config(page_title="Triad Protocol: balance", layout="wide")


def warehouse_choices() -> dict[str, Path]:
    """TRIAD_DUCKDB_PATH first if set, then the full warehouse, then the sample."""
    choices: dict[str, Path] = {}
    env_path = os.environ.get("TRIAD_DUCKDB_PATH")
    if env_path and Path(env_path).exists():
        choices[f"env: {Path(env_path).name}"] = Path(env_path)
    choices.update({label: path for label, path in WAREHOUSES.items() if path.exists()})
    return choices


@st.cache_data(show_spinner=False)
def load(path: str, modified: float) -> dict[str, pd.DataFrame]:
    """Run every query on a short-lived read-only connection.

    The connection is closed straight away so `make full` can rebuild the file while the
    dashboard is open; ``modified`` (the file mtime) invalidates the cache after a rebuild.
    """
    with duckdb.connect(path, read_only=True) as con:
        frames = {
            "kpis": q.kpis(con),
            "funnel": q.mission_funnel(con),
            "floors": q.floor_difficulty(con),
            "heroes": q.hero_performance(con),
            "abilities": q.ability_usage(con),
        }
    frames["findings"] = q.findings_from(frames["kpis"], frames["floors"], frames["heroes"])
    return frames


def policy_color(policies: list[str]) -> alt.Color:
    """Colour encoding with a fixed policy -> colour mapping."""
    domain = [p for p in POLICY_COLORS if p in policies] + [
        p for p in policies if p not in POLICY_COLORS
    ]
    return alt.Color(
        "policy:N",
        title="Policy",
        scale=alt.Scale(domain=domain, range=[POLICY_COLORS.get(p, "#FFFFFF") for p in domain]),
    )


def show(chart: alt.Chart) -> None:
    st.altair_chart(chart, width="stretch")


# --------------------------------------------------------------------------- sidebar
choices = warehouse_choices()
if not choices:
    st.error("No warehouse found. Run `make sample` (or `make full`) in analytics/ first.")
    st.stop()

with st.sidebar:
    st.header("Data")
    label = st.selectbox("Warehouse", list(choices))
    path = choices[label]
    data = load(str(path), path.stat().st_mtime)
    all_policies = list(data["kpis"]["policy"])
    picked = st.multiselect("Policies", all_policies, default=all_policies)
    st.caption(
        "Policies are the simulator's party AIs: **greedy** plays like a competent player, "
        "**random** picks any legal action, **attack_only** never uses abilities. "
        "Human data shows as **player**."
    )
    st.caption(
        f"File: `{path.relative_to(ANALYTICS_DIR) if path.is_relative_to(ANALYTICS_DIR) else path}`"
    )

if not picked:
    st.info("Pick at least one policy.")
    st.stop()


def only(frame: pd.DataFrame) -> pd.DataFrame:
    return frame[frame["policy"].isin(picked)]


color = policy_color(picked)

# --------------------------------------------------------------------------- header
st.title("Triad Protocol: balance dashboard")
st.caption(
    "Meridian Spire missions, from telemetry modelled by dbt. Each section answers one "
    "balance question; the Findings at the bottom are computed from the same data."
)

policy_rank = {p: i for i, p in enumerate(POLICY_COLORS)}  # same order as the legends
kpi = only(data["kpis"]).sort_values("policy", key=lambda s: s.map(policy_rank))
for column, row in zip(st.columns(len(kpi)), kpi.itertuples(), strict=True):
    with column:
        st.markdown(
            f"<span style='color:{POLICY_COLORS.get(row.policy, '#FFFFFF')};font-weight:700'>"
            f"{row.policy}</span> · {row.runs} runs",
            unsafe_allow_html=True,
        )
        st.metric("Missions completed", f"{row.completion_rate:.1%}")
        st.metric("Battles", f"{row.battles:,}")
        st.metric("Mean turns per battle", f"{row.mean_turns:.1f}")
        st.metric(
            "Party crit rate",
            f"{row.party_crit_rate:.1%}",
            delta=f"{100 * (row.party_crit_rate - q.DESIGNED_CRIT_RATE):+.1f} pp vs designed "
            f"{q.DESIGNED_CRIT_RATE:.0%}",
            delta_color="off",
        )

# --------------------------------------------------------------------------- funnel
st.header("Where do runs fail?")
st.caption(
    "Share of started missions that reach each step. A drop between two steps is the "
    "floor where runs end."
)
funnel = only(data["funnel"])
step_order = list(q.FUNNEL_STEPS.values())
show(
    alt.Chart(funnel)
    .mark_bar()
    .encode(
        x=alt.X("step:N", sort=step_order, title=None, axis=alt.Axis(labelAngle=0)),
        xOffset=alt.XOffset("policy:N", sort=list(POLICY_COLORS)),
        y=alt.Y("share_of_started:Q", title="Share of started runs", axis=alt.Axis(format="%")),
        color=color,
        tooltip=["policy", "step", "runs", alt.Tooltip("share_of_started:Q", format=".1%")],
    )
    .properties(height=280)
)

# --------------------------------------------------------------------------- floors
st.header("Which floor is hard?")
st.caption(
    "Left: battle win rate per floor (the axis starts near the lowest value so small gaps "
    "show; it is not zero-based). Right: share of the party's starting HP lost per battle."
)
floors = only(data["floors"])
left, right = st.columns(2)
with left:
    low = min(0.9, floors["win_rate"].min())  # 90% floor keeps tiny gaps from looking huge
    show(
        alt.Chart(floors)
        .mark_line(point=alt.OverlayMarkDef(size=80))
        .encode(
            x=alt.X("floor:O", title="Floor", axis=alt.Axis(labelAngle=0)),
            y=alt.Y(
                "win_rate:Q",
                title="Win rate",
                scale=alt.Scale(domain=[low, 1]),
                axis=alt.Axis(format="%"),
            ),
            color=color,
            tooltip=[
                "policy",
                "floor",
                "battles",
                "wins",
                "losses",
                alt.Tooltip("win_rate:Q", format=".1%"),
            ],
        )
        .properties(height=280)
    )
with right:
    show(
        alt.Chart(floors)
        .mark_bar()
        .encode(
            x=alt.X("floor:O", title="Floor", axis=alt.Axis(labelAngle=0)),
            xOffset=alt.XOffset("policy:N", sort=list(POLICY_COLORS)),
            y=alt.Y(
                "mean_party_hp_lost_pct:Q",
                title="Party HP lost per battle",
                axis=alt.Axis(format="%"),
            ),
            color=color,
            tooltip=[
                "policy",
                "floor",
                alt.Tooltip("mean_party_hp_lost_pct:Q", format=".1%"),
                alt.Tooltip("mean_turns:Q", format=".1f", title="mean turns"),
            ],
        )
        .properties(height=280)
    )

# --------------------------------------------------------------------------- heroes
st.header("Who carries and who dies?")
heroes = only(data["heroes"])
equal_share = 1 / heroes["hero_id"].nunique()
st.caption(
    "Each point is one hero under one policy: share of the party's damage against the share "
    f"of battles the hero falls in. The dashed line is an equal split ({equal_share:.0%}); "
    "top-left is a carry, right is fragile."
)
points = alt.Chart(heroes).encode(
    x=alt.X("death_rate_per_battle:Q", title="Death rate per battle", axis=alt.Axis(format="%")),
    y=alt.Y(
        "damage_share:Q",
        title="Damage share",
        axis=alt.Axis(format="%"),
        scale=alt.Scale(zero=False),
    ),
    color=color,
    tooltip=[
        "policy",
        "hero_name",
        "role_label",
        "battles_played",
        "deaths",
        alt.Tooltip("damage_share:Q", format=".1%"),
        alt.Tooltip("death_rate_per_battle:Q", format=".1%"),
        alt.Tooltip("damage_per_action:Q", format=".2f"),
    ],
)
equal = (
    alt.Chart(pd.DataFrame({"y": [equal_share]}))
    .mark_rule(strokeDash=[4, 4], color="#5A6578")
    .encode(y="y:Q")
)
show(
    (
        equal
        + points.mark_circle(size=160, opacity=0.9)
        + points.mark_text(dx=10, align="left", color="#E6EDF3").encode(text="hero_name:N")
    ).properties(height=340)
)

# --------------------------------------------------------------------------- abilities
st.header("Do abilities matter?")
st.caption(
    "Party abilities only. Usage: share of a policy's decisions. Damage per use: HP removed "
    "per decision (shield, guard and focus deal none by design). Energy per use is the "
    "ability's cost, the same for every policy. Compare greedy with attack_only, which "
    "never uses abilities, and with the outcomes above."
)
abilities = only(data["abilities"])
order = abilities.groupby("ability_id")["uses"].sum().sort_values(ascending=False).index.tolist()
c1, c2, c3 = st.columns([2, 2, 1])
with c1:
    show(
        alt.Chart(abilities)
        .mark_bar()
        .encode(
            y=alt.Y("ability_id:N", sort=order, title=None),
            yOffset=alt.YOffset("policy:N", sort=list(POLICY_COLORS)),
            x=alt.X("usage_share:Q", title="Share of decisions", axis=alt.Axis(format="%")),
            color=color,
            tooltip=["policy", "ability_id", "uses", alt.Tooltip("usage_share:Q", format=".1%")],
        )
        .properties(height=360)
    )
with c2:
    show(
        alt.Chart(abilities)
        .mark_bar()
        .encode(
            y=alt.Y("ability_id:N", sort=order, title=None),
            yOffset=alt.YOffset("policy:N", sort=list(POLICY_COLORS)),
            x=alt.X("damage_per_use:Q", title="Damage per use"),
            color=color,
            tooltip=[
                "policy",
                "ability_id",
                "uses",
                "total_damage",
                alt.Tooltip("damage_per_use:Q", format=".2f"),
            ],
        )
        .properties(height=360)
    )
with c3:
    energy = abilities.groupby("ability_id", as_index=False)["energy_per_use"].max()
    show(
        alt.Chart(energy)
        .mark_bar(color=ENERGY_COLOR)
        .encode(
            y=alt.Y("ability_id:N", sort=order, title=None),
            x=alt.X("energy_per_use:Q", title="Energy per use"),
            tooltip=["ability_id", alt.Tooltip("energy_per_use:Q", format=".0f")],
        )
        .properties(height=360)
    )

# --------------------------------------------------------------------------- findings
st.header("Findings")
st.caption(
    "Generated from the warehouse on every load, over all its policies, so a rebalance "
    "shows up here as a before/after. They describe the data; design decisions stay with "
    "the designer."
)
for row in data["findings"].itertuples():
    marker = LOSS_COLOR if row.topic in {"Which floor is hard?", "Who dies?"} else "#00D9E6"
    st.markdown(
        f"<span style='color:{marker};font-weight:700'>{row.topic}</span> {row.finding}",
        unsafe_allow_html=True,
    )

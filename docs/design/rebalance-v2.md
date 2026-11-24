# Rebalance v2: attrition between floors (Phase 6)

Follows [rebalance-v1.md](rebalance-v1.md). v1 fixed Nova and made the boss a boss, but
missions got easier (greedy 100%), because the party healed to full between floors:
every battle was isolated, so playing well never carried forward.

## Change

| ID | File | Field | Old → New |
|---|---|---|---|
| C4 | `resources/missions/meridian_spire.tres` | `between_floor_hp_restore` (new `MissionData` field) | full heal (1.0) → **0.25** |
| C4 | `resources/battler_stats.gd` | `restore_for_new_floor(hp_fraction)` | heal to max → heal `ceil(fraction × max_hp)`, capped; a downed hero returns with that share (min 1 HP) |
| — | `project.godot` | `application/config/version` | `0.3.0-rebalance` → `0.4.0-rebalance-v2` |

Energy still refills between floors. The game scene and the simulator both read the value
from `MissionProgress.MERIDIAN_BETWEEN_FLOOR_HP_RESTORE`, so they cannot drift apart.

## Choosing the value: a sweep

Missions completed, 500 runs per policy, seed 1, with v1 applied:

| HP restored between floors | greedy | random | attack_only | greedy − attack_only |
|---|---|---|---|---|
| 100% (v1) | 100.0% | 99.2% | 99.8% | 0.2 pp |
| 35% | 97.0% | 80.2% | 68.6% | 28.4 pp |
| 30% | 95.2% | 75.2% | 62.2% | 33.0 pp |
| **25% (chosen)** | **91.6%** | **68.0%** | **52.2%** | **39.4 pp** |
| Target | 85–95% | 50–75% | 65–85% | ≥ 8 pp |

No value meets all three ranges: the attack_only range conflicts with the other two. 25%
puts the competent policy in the middle of its range and the naive one inside its range,
and makes the kit worth 39 pp of missions. attack_only (never uses abilities) is not a real
player style, so its range was relaxed.

## Before / after (greedy unless noted; v0 = baseline, v2 = shipped)

| Metric | v0 | v1 | v2 |
|---|---|---|---|
| Missions completed, greedy / random / attack_only | 99.0 / 96.8 / 99.0% | 100.0 / 99.2 / 99.8% | **91.6 / 68.0 / 52.2%** |
| Floor 3 win rate | 100.0% | 100.0% | **91.6%** |
| Floor 3 party HP lost | 29.7% | 41.2% | **60.7%** (the boss is the peak) |
| Nova death rate, floors 1–2 | 14.8% | — | **4.2%** |
| Nova death rate, all floors ÷ next hero | 2.6× | 1.9× | 1.6× |
| Nova damage share | 30.6% | 38.4% | 39.0% |
| Mean party energy at turn start | 98.4 | 51.5 | 51.0 |
| Mean turns per battle | 13.2 | 13.9 | 14.6 |

## Guardrails

| Guardrail | Limit | v2 |
|---|---|---|
| Floor 1 win rate, every policy | ≥ 99% | 100% |
| Floor 2 win rate, greedy | ≥ 96% | 100% |
| Mean turns per battle, greedy | ≤ 18 | 14.6 |
| Battles hitting the 400-turn cap | 0 | 0 |
| Party crit rate | 13–17% | 15.0% |
| gdUnit4, dbt tests, pytest | green | green |

## Still open

- Energy rarely blocks an ability (1.4% of party turns, target 15–35%). The kits now
  decide outcomes through HP efficiency, not energy scarcity. A v3 could raise ability
  costs if energy should be a real decision.
- Every hero dies more often on the boss floor (Nova 35%, Kael 24%, Rin 19% of floor 3
  battles, greedy). That is the intended climax, but worth a human playtest.

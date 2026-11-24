# Headless Battle Simulator (Phase 4B)

Plays full Meridian Spire missions with no scenes and no player, and writes the
**same telemetry events the game writes** (`docs/analytics/event-schema.md`),
tagged `source = "sim"`. It gives Phase 5 a large dataset and Phase 6 a
reproducible balance baseline even with few human playtesters.

## Run it

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://tools/sim/run_sim.gd -- \
  --runs 500 --seed 1 --policy greedy --out analytics/data/raw/sim [--deterministic-ids]
```

| Flag | Default | Meaning |
|---|---|---|
| `--runs` | 500 | Missions to play. |
| `--seed` | 1 | Base seed; run *i* uses `seed * 1000003 + i`. |
| `--policy` | `greedy` | `random`, `greedy` or `attack_only`. |
| `--out` | `analytics/data/raw/sim` | Output directory; relative paths resolve against the project root. |
| `--deterministic-ids` | off | Derive UUIDs and `ts_utc` from the seed (see Determinism). |

Output: `<out>/<policy>_seed<seed>.jsonl`, **replaced** on every invocation
(one file, no date, no rotation). The run ends by printing a summary: runs,
mission results, battles and win rate per floor, mean turns per battle, wall time.

`analytics/data/raw/` is git-ignored. A 20-run, deterministic-id sample lives in
`analytics/data/sample/greedy_seed1.jsonl` for CI and tests; regenerate it with
`--runs 20 --seed 1 --policy greedy --deterministic-ids --out analytics/data/sample`.
`analytics/.gdignore` keeps Godot from importing the data folder.

## What a run is

One run is one mission attempt, exactly as in the game:

1. `MissionProgress.start_meridian_spire()` emits `mission_start` and `floor_reached(1)`.
   The simulator uses its **own MissionProgress instance** (same script as the
   autoload, with `telemetry` injected), so the mission rules and events are
   the game's, not a copy.
2. Each floor: enemies from the real `MissionData` lineup
   (`EnemyRoster.build_enemies(get_current_floor_enemy_types(), floor)`), party
   from `HeroRoster.build_party()`, `BattleManager.setup_battle(...)`.
3. Turn loop, as in `BattleScene`: downed battlers are skipped, party members
   act through the policy, enemies through `EnemyAI` (same choice and targeting).
4. Win: `meridian_advance_floor()` (emits `floor_reached`) and
   `BattlerStats.restore_for_new_floor()` on the surviving party objects, as the
   game does between floors (a full restore), then the next floor. Rooftop win:
   `mark_rooftop_cleared()`, `finish_meridian_spire("completed")`.
5. Loss: `finish_meridian_spire("failed")`. A battle still running after
   400 manager turns is recorded as `battle_end.result = "quit"` and
   `mission_end.result = "abandoned"` (none happened in the baselines).

The autoload `Telemetry` is disabled for the process (without touching the
saved opt-in), so a sim never writes player data.

## Party policies (`scripts/sim/`)

All policies choose only from `PartyPolicy.legal_actions()`: a basic attack on
each reachable enemy, plus every affordable kit ability with each valid target.

| Policy | Rule | Purpose |
|---|---|---|
| `random` | Uniform over legal actions. | Lower bound for "a player who doesn't think". |
| `greedy` | Below 40% HP and unprotected: Shield, else Guard. Otherwise the action with the highest expected damage this turn (crit-weighted, mirrors the damage formula incl. guard, shield, defense, grenade splash); ties go to the lowest-HP target. | Approximates a competent player. |
| `attack_only` | Basic attack on a uniformly random reachable enemy. | Baseline: what the kits add over attacking. |

The kits have no heals and Shield/Guard are self-only, so greedy's "protect an
ally" rule reduces to protecting the actor itself.

`policy` is logged on `battle_start` and `mission_start` (optional field;
absent in player data).

## Determinism

- One `RandomNumberGenerator` per run, seeded `seed * 1000003 + run_index`,
  drives crit rolls (`BattleManager.rng`), enemy targeting (`EnemyAI`) and the
  policy. Runs do not share state, so run *i* is the same whatever `--runs` is.
- `duration_ms` in sim data uses a **virtual clock** (1 ms per event), not
  wall time, so it does not depend on machine speed. Use `turns` for pacing.
- Without `--deterministic-ids`, identical arguments give identical gameplay
  and payloads; only UUIDs (`event_id`, `session_id`, `run_id`, `battle_id`)
  and `ts_utc` differ.
- With `--deterministic-ids`, UUIDs come from an RNG seeded with `--seed`
  (separate from gameplay) and `ts_utc` = `2026-01-01T00:00:00Z` + virtual ms,
  so two runs are **byte-identical** (`cmp` passes; covered by `tests/test_sim.gd`).

## Baseline (seed 1, 500 runs each; Phase 4B, no balance changes)

| Policy | Completed | Failed | Floor 1 win | Floor 2 win | Floor 3 win | Mean turns / battle |
|---|---|---|---|---|---|---|
| `greedy` | 495 | 5 | 100.0% | 99.0% | 100.0% | 13.21 |
| `random` | 484 | 16 | 100.0% | 96.8% | 100.0% | 19.24 |
| `attack_only` | 495 | 5 | 100.0% | 99.0% | 100.0% | 13.82 |

Wall time: about 2 s per 500 runs on the dev Mac. Treat this as the "before" for Phase 6.

To load and model this data, see the [analytics pipeline](../../analytics/README.md).

# Telemetry Event Schema (v1)

Status: Phase 4A. Owner: analytics. Producer: `Telemetry` autoload
(`scripts/autoload/telemetry.gd`). Consumer: the Phase 5 pipeline (`analytics/`,
DuckDB now, Postgres-loadable later).

This document is the contract between the game and the data pipeline. The
in-code table `TelemetryService.EVENT_SCHEMAS` enforces the same rules at the
point of emission: an event with an unknown name, a missing required field, an
unexpected field or a wrongly typed field is **dropped with a `push_warning`**,
never written and never fatal.

## Design questions this data must answer

Every event below exists because a Phase 5 mart or Phase 6 balance decision
needs it. If a field has no consumer, it does not belong here.

| Question (Phase 5 dashboard / Phase 6 rebalance) | Answered by |
|---|---|
| Win rate by floor; is any floor a wall? | `battle_start`, `battle_end` -> `fct_battles` |
| Damage share per hero; is one hero carrying? | `action` -> `fct_actions` |
| Ability usage and energy pressure | `action`, `ability_unaffordable` |
| Crit and shield impact on outcomes | `action.is_crit`, `action.shield_absorbed` |
| Turns per battle; are fights dragging? | `turn_start`, `battle_end.turns` |
| Where do players drop out of the mission? | `mission_start`, `floor_reached`, `mission_end`, `battle_end.result = quit` |
| Which battlers die first / most? | `battler_down` -> `dim_battlers` |

## File format and location

- **JSON Lines** (one UTF-8 JSON object per line, `\n` terminated).
- Player data: `user://telemetry/events_YYYY-MM-DD.jsonl` (UTC date).
- Simulator data: its own sink and directory, `source = "sim"` on every row,
  so synthetic and human data can never be mixed by accident.
- A file that would grow past ~5 MB rotates to `events_YYYY-MM-DD_1.jsonl`,
  `_2`, and so on.
- Lines are buffered in memory and flushed on `battle_end`, on scene change,
  when the buffer reaches 64 lines, and on quit.

## Envelope (every event)

All envelope fields are present on every line. Nullable fields are written as
JSON `null`, never omitted, so the staging layer can rely on a fixed column set.

| Field | Type | Null? | Description |
|---|---|---|---|
| `schema_version` | int | no | Envelope + payload contract version. This document = `1`. Bump on any breaking change. |
| `event_id` | string (UUID v4) | no | Unique per event. Primary key in staging; used to de-duplicate re-uploads. |
| `event_name` | string | no | One of the names in "Events" below. |
| `event_seq` | int | no | Monotonic counter within the session (1, 2, 3...). Orders events emitted in the same millisecond. |
| `ts_utc` | string (ISO-8601, ms, `Z`) | no | Emission time in UTC, e.g. `2026-11-24T14:03:07.512Z`. |
| `session_id` | string (UUID v4) | no | Random, regenerated every launch. Not derived from any hardware or account ID. |
| `run_id` | string (UUID v4) | yes | One mission attempt (Meridian Spire start -> end). `null` for a battle launched outside a mission. |
| `battle_id` | string (UUID v4) | yes | One battle (one floor fight). `null` outside a battle. |
| `source` | string enum | no | `"player"` (a human playing) or `"sim"` (headless simulator). |
| `game_version` | string | no | `application/config/version` from `project.godot` (`"dev"` if unset). |
| `platform` | string | no | `OS.get_name()`: `macOS`, `Windows`, `Linux`, `Web`... Coarse by design. |
| `payload` | object | no | Event-specific fields, below. `{}` when the event has none. |

Envelope fields are flat columns in staging; `payload` is unnested per event
type in `stg_<event_name>` models.

## Identifiers

| Id | Form | Stable across sessions? |
|---|---|---|
| Hero `battler_id` | `HeroData.id` (e.g. `kael`, `brick`); `hero_<slot>` fallback if a roster entry is missing | yes |
| Enemy `battler_id` | `<enemy_type>_<slot>` (e.g. `drone_0`, `drone_1`) | yes, within a lineup |
| `enemy_type` | `EnemyArchetype.id` | yes |
| `ability_id` | `BattleManager.ABILITY_COSTS` key; basic attack = `"attack"` | yes |
| `side` | `"party"` or `"enemy"` | n/a |

`(battle_id, battler_id)` is the natural key of a battler-in-battle.

## Events

Types: `int`, `float`, `bool`, `string`, `string[]`. **R** = required,
O = optional (may be absent or `null`).

### `session_start`
Emitted when the `Telemetry` autoload starts with opt-in on, or the moment the
player opts in.

| Field | Type | | Description |
|---|---|---|---|
| `build` | string | R | `"debug"` or `"release"`. |
| `headless` | bool | R | True when running without a display (CI, simulator). |

### `session_end`
Emitted on quit (window close or the Quit button). This is the plan's `quit` event.

| Field | Type | | Description |
|---|---|---|---|
| `reason` | string | R | `"quit"`. |
| `duration_ms` | int | R | Session wall-clock length. |
| `events_emitted` | int | R | Events accepted this session (excluding this one). Lets staging detect lost lines. |

### `mission_start`
`MissionProgress.start_meridian_spire()`. Opens a new `run_id`.

| Field | Type | | Description |
|---|---|---|---|
| `mission_id` | string | R | `"meridian_spire"`. |
| `max_floor` | int | R | Floors in the mission (3). |

### `floor_reached`
On mission start (floor 1) and on every `meridian_advance_floor()`.

| Field | Type | | Description |
|---|---|---|---|
| `mission_id` | string | R | |
| `floor` | int | R | 1-based floor now active. |

### `mission_end`
`MissionProgress.finish_meridian_spire()`. Closes the `run_id`. *Addition beyond
the original brief*: the funnel needs an explicit terminal step, otherwise
"abandoned" and "still playing" look the same.

| Field | Type | | Description |
|---|---|---|---|
| `mission_id` | string | R | |
| `result` | string | R | `"completed"` (rooftop cleared), `"failed"` (party wiped), `"abandoned"` (left to menu). |
| `max_floor_reached` | int | R | Highest floor reached in this run. |

### `battle_start`
`BattleManager.setup_battle()`. Opens a new `battle_id`.

| Field | Type | | Description |
|---|---|---|---|
| `floor` | int | R | Combat floor (1 when no mission is active). |
| `mission_id` | string | O | `null` outside a mission. |
| `party_ids` | string[] | R | Hero `battler_id`s in slot order. |
| `enemy_ids` | string[] | R | Enemy `battler_id`s in slot order. |
| `enemy_type_ids` | string[] | R | `enemy_type` per slot. |
| `party_hp_total` | int | R | Sum of party HP at start (floors fully restore the party). |
| `enemy_hp_total` | int | R | Sum of enemy HP at start. |
| `seed` | int | O | Crit RNG seed when the battle uses a seeded RNG (simulator); absent for live play. |

### `turn_start`
`BattleManager._emit_turn_started()`, after the per-turn energy restore. Skipped for a battler downed earlier in the same round (its slot in the round order is not a real turn).

| Field | Type | | Description |
|---|---|---|---|
| `turn_number` | int | R | 1-based, counts every turn in the battle. |
| `round_number` | int | R | 1-based; a round = every living battler acts once. |
| `actor_id` | string | R | |
| `actor_side` | string | R | |
| `actor_hp` | int | R | |
| `actor_energy` | int | R | Energy after the restore. |

### `action`
**Grain: one row per resolved hit**, plus one row for a non-damaging ability
(fly, shield, guard, focus) with the actor as target. A grenade that hits three
enemies is three rows sharing `action_seq`, with `hit_index` 0, 1, 2. Damage
share per hero is then a plain `SUM(damage)`.

| Field | Type | | Description |
|---|---|---|---|
| `turn_number` | int | R | Joins to `turn_start`. |
| `action_seq` | int | R | 1-based per battle; one per player/AI decision. |
| `hit_index` | int | R | 0-based hit within the decision. |
| `actor_id` / `actor_side` | string | R | |
| `ability_id` | string | R | `"attack"` for the basic attack. |
| `target_id` / `target_side` | string | R | Actor itself for self-buffs. |
| `damage` | int | R | HP actually removed (after defense, guard, shield). |
| `hit_kind` | string | R | `"hit"`, `"crit"`, `"absorb"` (all soaked by shield), `"miss"`, `"effect"` (non-damaging ability). |
| `is_crit` | bool | R | Crit rolled (true even if the shield then soaked it). |
| `shield_absorbed` | int | R | Shield HP consumed by this hit. |
| `energy_cost` | int | R | Charged on `hit_index = 0` only, 0 on later hits, so `SUM` is correct. |
| `target_hp_before` / `target_hp_after` | int | R | |
| `is_kill` | bool | R | `hp_before > 0 and hp_after == 0`. |

### `battler_down`
Same call as the killing `action`, immediately after it.

| Field | Type | | Description |
|---|---|---|---|
| `turn_number` | int | R | |
| `battler_id` / `side` | string | R | Who fell. |
| `killer_id` / `killer_side` | string | R | |
| `ability_id` | string | R | Killing ability. |

### `ability_unaffordable`
`BattleManager.perform_ability()` refused for lack of energy. Measures energy
pressure the UI otherwise hides (disabled buttons).

| Field | Type | | Description |
|---|---|---|---|
| `turn_number` | int | R | |
| `actor_id` / `actor_side` | string | R | |
| `ability_id` | string | R | |
| `energy_cost` | int | R | |
| `energy_available` | int | R | |

### `battle_end`
`BattleManager._check_battle_end()` (win/loss) or the BattleManager leaving the
tree / being re-set-up mid-fight (quit). Triggers a flush. Closes `battle_id`.

| Field | Type | | Description |
|---|---|---|---|
| `result` | string | R | `"win"`, `"loss"`, `"quit"`. |
| `turns` | int | R | Total turns taken. |
| `rounds` | int | R | Rounds started. |
| `duration_ms` | int | R | Wall clock from `battle_start`. Meaningless for `sim`; use `turns`. |
| `surviving_party` | string[] | R | Hero ids still alive. |
| `party_hp_remaining` | int | R | |
| `enemies_remaining` | int | R | |

## Example lines

```json
{"schema_version":1,"event_id":"5b0c...","event_name":"battle_start","event_seq":4,"ts_utc":"2026-11-24T14:03:07.512Z","session_id":"a1f3...","run_id":"77c2...","battle_id":"e9d4...","source":"player","game_version":"0.4.0","platform":"macOS","payload":{"floor":1,"mission_id":"meridian_spire","party_ids":["kael","brick","sage"],"enemy_ids":["drone_0","drone_1"],"enemy_type_ids":["drone","drone"],"party_hp_total":270,"enemy_hp_total":100}}
{"schema_version":1,"event_id":"c40e...","event_name":"action","event_seq":6,"ts_utc":"2026-11-24T14:03:09.020Z","session_id":"a1f3...","run_id":"77c2...","battle_id":"e9d4...","source":"player","game_version":"0.4.0","platform":"macOS","payload":{"turn_number":1,"action_seq":1,"hit_index":0,"actor_id":"kael","actor_side":"party","ability_id":"attack","target_id":"drone_0","target_side":"enemy","damage":17,"hit_kind":"crit","is_crit":true,"shield_absorbed":0,"energy_cost":0,"target_hp_before":50,"target_hp_after":33,"is_kill":false}}
{"schema_version":1,"event_id":"0a9b...","event_name":"battle_end","event_seq":41,"ts_utc":"2026-11-24T14:04:30.871Z","session_id":"a1f3...","run_id":"77c2...","battle_id":"e9d4...","source":"player","game_version":"0.4.0","platform":"macOS","payload":{"result":"win","turns":18,"rounds":4,"duration_ms":83359,"surviving_party":["kael","sage"],"party_hp_remaining":121,"enemies_remaining":0}}
```

Real captured lines are produced by the verification script (see the Phase 4A
report); the values above are illustrative.

## Mapping to Phase 5 marts

| Mart | Grain | Built from |
|---|---|---|
| `stg_events` | one event | every line; envelope columns + raw `payload` JSON; de-dup on `event_id` |
| `fct_battles` | one battle (`battle_id`) | `battle_start` (floor, lineup, hp totals) joined to `battle_end` (result, turns, duration, survivors); a `battle_start` with no `battle_end` = crashed/lost data, flagged by a DQ test |
| `fct_actions` | one hit | `action`, joined to `fct_battles` for floor/result; `ability_unaffordable` as a sibling `fct_ability_denials` or an `is_denied` union |
| `dim_battlers` | one battler per battle (`battle_id`, `battler_id`) | `battle_start.party_ids/enemy_ids/enemy_type_ids` unnested, plus `battler_down` (died, turn of death, killer) |
| `fct_mission_funnel` | one run (`run_id`) | `mission_start` -> `floor_reached` (1..3) -> `battle_end` per floor -> `mission_end.result` |
| session health | one session | `session_start`, `session_end`; `events_emitted` vs counted rows = loss rate |

### Postgres readiness

Every field maps to a native column: UUIDs -> `uuid`, `ts_utc` -> `timestamptz`,
`string[]` -> `text[]`, `payload` -> `jsonb`. A future loader can `COPY` the
JSONL into `raw_events(event_id uuid primary key, ..., payload jsonb)` with
`ON CONFLICT (event_id) DO NOTHING` for idempotent re-uploads. No HTTP code
exists yet (out of scope for 4A).

## Data-quality rules (for Phase 5 CI)

- `event_id` unique; envelope fields non-null except `run_id`, `battle_id`.
- `schema_version` in the supported set.
- `action.damage >= 0`, `target_hp_after <= target_hp_before`,
  `is_kill = (target_hp_before > 0 and target_hp_after = 0)`.
- `battle_end.turns >= 1`; every `battle_id` with `battle_start` has exactly one `battle_end`.
- `source = 'sim'` rows never share a `session_id` with `source = 'player'` rows.

## Privacy

- **Opt-in only.** The toggle in Options is OFF by default. While off,
  `track()` is a no-op: nothing is buffered, nothing is written.
- **Anonymous.** `session_id` is a random UUID v4, regenerated every launch.
  No hardware IDs, account names, OS user names, IP addresses, locale or
  free text are collected. There is no persistent player ID, so sessions
  cannot be linked to each other or to a person.
- **Local only.** Data stays in the game's `user://telemetry/` folder on the
  player's device. Phase 4A has no network code.
- **Gameplay only.** Every field is a game-state value listed above; the
  schema validator drops any field not in this document.
- Opting out stops collection immediately. Files already written stay on disk
  until the player deletes the folder (open question: add a "Delete local data"
  button?).
- Changing what is collected requires bumping `schema_version` and updating
  this document.

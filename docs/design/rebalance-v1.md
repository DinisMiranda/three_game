# Rebalance v1: proposal (Phase 6)

Status: **PROPOSAL, awaiting approval.** No `.tres` or code has been changed.
Baseline: simulator seed 1, 500 runs × 3 policies (`docs/analytics/simulator.md`).

## Design intent (the yardstick)

A competent player (`greedy`) usually wins (85–95% of missions). A naive one
(`attack_only`, `random`) struggles noticeably more. Kits matter, the boss feels
like a boss, and no hero is dead weight or a trap pick.

## Root causes

Figures marked *(formula)* come from the damage formula in `BATTLE_SYSTEM.md`
applied to the `.tres` values: `raw = atk*mult - def/2`, then `- def` again in
`take_damage`. So defence counts about 1.5 times. Figures marked *(measured)* are
the known baseline findings. **The warehouse was not queried for this draft.**
The confirming queries are listed under Measurement.

| # | Finding | Root cause |
|---|---|---|
| R1 | Abilities do not change outcomes: greedy 99.0% = attack_only 99.0% missions; only 0.6 fewer turns *(measured)* | Ability value per use is tiny against def 3 enemies *(formula)*. Strike gives Rin 9 vs 6 from an attack. Grenade on floor 2 gives 10 + 2 splash vs 10. **Snipe can never be used**: it needs a flying target, and no enemy has Fly. Nova's Fly is worth 0 expected damage, so greedy never picks it. |
| R2 | Energy never limits; `ability_unaffordable` is 0 | Heroes start at 100 energy (`hero_roster.gd` sets current = max) and regain 20 a turn against costs of 20–25. A hero gets about 3–5 turns a battle, so net drain is about −5 a turn from a full bar. Also, `PartyPolicy.legal_actions()` drops unaffordable abilities, **so the sim can never emit `ability_unaffordable`**. It needs a different metric (see M4). |
| R3 | Floor 3 boss never lost; floor 2 is the only wall (~57% party HP lost) *(measured)* | Custodian on floor 3 has 75 HP and def 3, which is less total HP than floor 2's Warden + Hound (50 + 60 = 110) with one enemy turn per round instead of two. Its Tactician AI uses **Focus while above 50% HP**, a turn with no damage. The party deals about 23 a round *(formula)*, so the boss dies in about 3.5 rounds and lands about 2 damaging actions (≈ 58 + 34 = 92 damage, spread at random). The difficulty curve goes the wrong way: floor 2 is harder than floor 3. |
| R4 | Nova dies in 14.4% of battles, 2.6× the next hero *(measured)* | She has the lowest HP (78 vs 86/92) and the lowest def (3 vs 5). Because defence counts about 1.5×, a floor-2 Hound hits her for 16 vs 13 on Kael and Rin, and a Warden for 14 vs 11. She falls in about 5 Hound hits vs 7–8 for the others. Her kit gives her no defence that greedy uses (no Shield or Guard), and her damage button (Snipe) is dead. Likely killer: the floor-2 Hound (melee, Frenzy below 50%). Confirm with M5. |

Not changed on purpose: the full HP restore between floors. It keeps floors
independent, which keeps this before/after clean. Revisit in v2. Floor 2 is also
unchanged: it is the right difficulty for a middle floor.

## Proposed changes

| ID | File | Field | Old → New |
|---|---|---|---|
| C1 | `resources/enemies/custodian.tres` | `ai_profile` | `0` (Tactician) → `1` (Berserker) |
| C1 | `resources/enemies/custodian.tres` | `base_hp` | `55` → `75` (floor 3 HP 75 → 95) |
| C1 | `resources/enemies/custodian.tres` | `defense` | `3` → `5` |
| C2 | `resources/heroes/nova.tres` | `abilities[1]` | `{"id":"snipe","name":"Snipe"}` → `{"id":"slash","name":"Snap Shot"}` |
| C2 | `resources/heroes/nova.tres` | `defense` / `max_hp` | `3` → `4` / `78` → `84` |
| C3 | `scripts/battle/battle_manager.gd` | `ENERGY_RESTORE_PER_TURN` | `20` → `10` |
| C3 | `resources/heroes/{kael,nova,rin}.tres` | `max_energy` | `100` → `60` |

**C1: make the boss a boss (fixes R3, drives R1).** Berserker attacks every turn
and uses Frenzy (two hits) below 50% HP. That gives a visible "phase 2" enrage
instead of wasted Focus turns. Def 5 is an armoured target: an attack deals Kael 7,
Nova 4 and Rin 3, but Strike gives Rin 8 (2.7×) and Snap Shot gives Nova 7 (1.75×)
*(formula)*. So the kit is the answer to the boss. Party damage per round:
attack_only ≈ 14, greedy ≈ 19.5. That is about 7 rounds vs about 5, and roughly
187 vs 136 boss damage into a 262 HP party. The boss is melee, so Nova's Fly is a
real counter to it, which humans and `random` can find. This is a hidden counter
that greedy does not model.

**C2: Nova stops being a trap pick (fixes R4, R1).** Slash is already in
`ABILITY_COSTS` (15, ×1.35) but no hero has it. Swapping it in for the
never-legal Snipe turns a dead button into a cheap damage option. Snipe stays in
code for a future flying enemy. Def 3 → 4 and HP 78 → 84 make the Hound hit her
for 14 (was 16) and the Warden for 12 (was 14). She now falls in 6 Hound hits,
still the most fragile hero but no longer an outlier.

**C3: energy becomes a decision (fixes R2).** Start at 60 and regain 10, so Rin
(Strike 25) can Strike on turns 1–3 and then about every other turn. Kael
(Grenade 22) gets 3 Grenades in 4 turns. Nova (Snap Shot 15) is rarely blocked.
Shield (20) now competes with Strike for Rin's energy.

## Targets (hypotheses)

| Metric (source) | Before | Target |
|---|---|---|
| Missions completed, greedy (`fct_mission_funnel.mission_result`) | 99.0% | **85–95%** |
| Missions completed, attack_only | 99.0% | 65–85%, and **greedy − attack_only ≥ 8 pp** |
| Missions completed, random | 96.8% | 50–75% (still beatable) |
| Floor 3 `win_rate`, greedy / attack_only (`mart_floor_difficulty`) | 100% / 100% | 88–96% / 70–88% |
| Floor 3 `mean_party_hp_lost_pct` vs floor 2, greedy | below floor 2 | **≥ floor 2** (the boss is the peak) |
| Nova `death_rate_per_battle`, floors 1–2 only, greedy (M5) | ~14.4% (all floors) | 6–9% |
| Nova death rate ÷ next-highest hero, all floors | 2.6× | ≤ 1.5× |
| Nova `damage_share` (`mart_hero_performance`) | query (M3) | rises; every hero between 20% and 45% |
| Snipe uses / Slash uses by Nova, greedy (`fct_actions.ability_id`) | 0 / 0 | n/a / > 30% of Nova's actions |
| Hero turns with energy < cheapest kit cost, greedy (M4) | ~0% | 15–35% |

## Measurement protocol

1. Set `application/config/version` in `project.godot` to `0.3.0-rebalance` (it is
   unset today, so the baseline reads `dev`). This is part of the change set.
2. **Use a new output directory.** The sim *replaces* `<out>/<policy>_seed1.jsonl`,
   so reusing `data/raw/sim` destroys the baseline. Run the three policies:
   `--runs 500 --seed 1 --policy {greedy,random,attack_only} --out analytics/data/raw/sim_v030`.
3. Build a separate warehouse (the marts group by `policy`, not `game_version`):
   ingest `data/raw/sim_v030/*.jsonl` into `warehouse/triad_v030.duckdb` and run
   dbt with `TRIAD_DUCKDB_PATH` set to it. Compare it with `triad.duckdb` using the
   same queries. Keep the baseline warehouse untouched.
4. Queries (run on both warehouses):
   - **M1** `mart_floor_difficulty`: `win_rate`, `mean_turns`, `mean_party_hp_lost_pct` by policy × floor.
   - **M2** `fct_mission_funnel`: share of `mission_result = 'completed'` by policy.
   - **M3** `mart_hero_performance`: `damage_share`, `damage_per_action`, `death_rate_per_battle`, `energy_spent`.
   - **M4** `staging.stg_turn_start` for party actors: share of turns with `actor_energy` below the hero's cheapest kit cost. Do not use `ability_unaffordable` (see R2).
   - **M5** `fct_battle_participants` joined to `fct_battles`: Nova `is_down` by `floor`, plus `killer_id` and `killed_by_ability_id` for Nova's deaths. Run it on the baseline **before approving** to confirm the Hound hypothesis in R4.
   - **M6** `fct_actions`: uses and mean `damage` by `actor_key` × `ability_id`. Compare with `attack` for the same actor and floor.
5. Optional ablation for attribution: re-run with C1 + C2 only (version
   `0.3.0-rb-noC3`) to separate the energy effect from the boss effect.

### Guardrails (must not regress)

| Guardrail | Baseline | Limit |
|---|---|---|
| Floor 1 `win_rate`, every policy | 100% | ≥ 99% (onboarding floor) |
| Floor 2 `win_rate`, greedy | 99.0% | ≥ 96% (C3 must not turn floor 2 into the wall again) |
| `mean_turns` per battle, greedy | 13.21 | ≤ 18 (pacing; random may rise) |
| Battles ending `quit` (400-turn cap) | 0 | 0 |
| Party `crit_rate` | ~15% | 13–17% (RNG sanity) |
| dbt tests, pytest, gdUnit4 | green | green. Check for tests that hardcode Nova's stats, Snipe, or regen 20 |

## Risks and side effects

- **C3 also slows enemy regen**, because the constant is shared. The Warden's
  Barrage (35) comes up less often, so floor 2 may get slightly easier. The C1 boss
  maths uses regen 10. A hero-only regen would need a code change.
- **Over-tuning the boss.** The 95 HP / def 5 numbers are formula estimates, not
  sims. If greedy floor 3 falls below 85%, go back to def 4 first, then HP.
- **Greedy never uses Fly**, so the measured boss difficulty is an upper bound
  for a player who finds the Fly counter.
- The Slash hint text in code says "Strong melee hit", which does not fit Nova.
  It is cosmetic and needs a one-line code edit, or a decision to keep "Slash".
- Hand-edited `.tres`: never change `format=`. Run `godot --headless --path . --import`
  afterwards (`.claude/rules/scene-files.md`).

## Decision needed

1. Approve C1, C2 and C3 as one change set, or C1 + C2 only, with C3 left to v2.
2. Boss armour: def 5 (recommended; Strike 2.7× attack) or def 4 (gentler; Strike 1.9×).
3. Nova's second ability: Slash, shown as "Snap Shot" (recommended, data-only), or keep Snipe and make it usable on any target (code change).
4. Approve the `project.godot` version bump and the separate `sim_v030` / `triad_v030.duckdb` outputs.
5. Run query M5 on the baseline before editing, to confirm who kills Nova.

## Results (v0.3.0-rebalance, 500 runs × 3 policies, seed 1)

Measured on `warehouse/triad_v030.duckdb` against the baseline `warehouse/triad.duckdb`.

| Metric | Before | After v1 | Target | Verdict |
|---|---|---|---|---|
| Missions completed, greedy / random / attack_only | 99.0 / 96.8 / 99.0% | 100.0 / 99.2 / 99.8% | 85–95 / 50–75 / 65–85% | **Missed** (easier, not harder) |
| Nova death rate, greedy | 13.3% | 5.9% | 6–9% | Met |
| Nova damage share, greedy | 30.6% | 38.4% | rises, 20–45% | Met |
| Floor 3 party HP lost, attack_only / greedy | 32.3 / 29.7% | 59.5 / 41.2% | ≥ floor 2 | Met for attack_only and random, not greedy |
| Floor 3 mean turns, greedy vs attack_only | 12.3 vs 12.7 | 17.3 vs 23.9 | kits matter | Met (pace) |
| Party energy at turn start (mean / min) | 98.4 / 50 | 51.5 / 10 | pressure | Partly met |
| Turns with energy below the cheapest kit cost | 0.0% | 0.9% | 15–35% | **Missed** |
| Guardrails (floor 1 ≥ 99%, no 400-turn cap, crit 13–17%, tests green) | | all hold | | Met |

**Why the headline missed.** Nova dying on floor 2 was the only real cause of defeat;
fixing her removed it. And because `restore_for_new_floor()` heals the party to full
between floors, every battle is isolated: playing well only changes HP lost inside a
battle, which never carries forward. Kits now change *how fast* a fight goes, but not
*whether* a run survives.

**Next (v2).** Make the mission an attrition run: restore only part of max HP between
floors (energy still refills), so HP efficiency (a skill and kit outcome) decides who
reaches and beats the boss. See `rebalance-v2.md`.

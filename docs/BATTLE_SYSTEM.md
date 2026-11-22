# Battle System

How turns, turn order, abilities, and combat work.

## Rules

- **Sides**: 3 party (allies, `BattleManager.PARTY_SIZE`) vs 1–4 enemies (`MAX_ENEMIES`). The Meridian Spire run uses 1 enemy on floors 1 and 3 and 2 enemies on floor 2.
- **Turn order**: Each round, every **alive** battler is ordered by **speed** (highest first). They act in that order. When everyone has acted once, the round ends and order is recalculated for the next round (so speed and deaths change who goes first).
- **Energy**: Every battler has `max_energy` 100. At the start of each of its turns a battler restores 20 energy (`ENERGY_RESTORE_PER_TURN`). Abilities spend energy; the basic Attack is free.
- **Attack**: `BattleManager.perform_attack()` computes damage and applies it with `BattlerStats.take_damage()` (see *Damage resolution*). Attacks have a 15% crit chance (x1.5 damage).
- **Flying**: A flying battler can only be hit by a ranged attacker (`is_ranged`); `Snipe` hits only flying targets. Flying and Guard are cleared at the start of that battler’s next turn.
- **Win/lose**: At the end of a round, if all party are dead → defeat; if all enemies are dead → victory. BattleManager emits `battle_ended(party_wins)`.

## Abilities

Costs live in `BattleManager.ABILITY_COSTS`; the hint text shown as a tooltip is in `get_ability_hint()`.

| Id | Cost | Effect (from `perform_ability`) |
|----|------|---------------------------------|
| `grenade` | 22 | Hit on the target (x1.0) plus splash on the other living enemies (x0.45 each). |
| `guard` | 20 | Halves incoming damage until this battler’s next turn. |
| `fly` | 25 | Becomes flying; melee attackers cannot target it. |
| `snipe` | 30 | x1.8 hit; only usable on a flying target. |
| `strike` | 25 | Hit that ignores defense. |
| `shield` | 20 | Shield equal to 50% of max HP for 3 rounds. |
| `slash` | 15 | x1.35 hit. Defined in the manager but not assigned to any hero or enemy. |
| `ranged_shot` | 20 | One normal hit (enemy ability). |
| `barrage` | 35 | Two normal hits (enemy ability). |
| `focus` | 18 | Attack buff of +50% of base attack for 2 rounds (enemy ability). |
| `frenzy` | 22 | Two normal hits (enemy ability; the AI uses it below 50% HP). |

Hero kits come from `HeroRoster`: **Kael** (Grenadier): Grenade, Guard. **Nova** (Skirmisher): Fly, Snipe. **Rin** (Field Support): Strike, Shield. Brick (Guard, Strike) and Sage (Shield, Strike) are defined with `enabled: false`: they are not in the combat party and only appear in story scenes.

## Damage resolution

1. `perform_attack` returns a miss if the target cannot be attacked (dead, or flying vs a non-ranged attacker; for `snipe`, a non-flying target).
2. `raw = int(attack_power * damage_mult) - int(defense / 2)`, floor 1. `attack_power` is attack plus any Focus buff. A crit multiplies `damage_mult` by 1.5.
3. `BattlerStats.take_damage(damage, ignore_defense)`: Guard halves the damage (rounded up); an active shield absorbs first (1:1); any overflow is reduced by the target’s full `defense` (skipped for `strike`), minimum 0.
4. The result is classified as `hit`, `crit`, `absorb` (shield took everything) or `miss` (0 damage) and appended to `last_hit_results` for the UI.

## Enemy AI

Implemented in `enemy_ai.gd` (`EnemyAI.choose_action`, `EnemyAI.pick_target`), by the archetype's AI profile (`EnemyRoster.get_ai_profile`):

- **Profile 0**: Focus when HP is above 50%, else Barrage, else Ranged Shot, else a basic attack.
- **Profile 1**: Frenzy when HP is below 50%, else a basic attack.
- **Profile 2**: Guard when HP is below 40%, else a basic attack.

Each action picks a random valid party target. Before acting, the enemy slot flashes and the scene waits about 0.9s.

## Turn flow (in code)

1. **setup_battle(party, enemies)**  
   - Stores party and enemies, calls `_build_turn_order()`, sets `_current_turn_index = 0`, emits `turn_order_updated`, then emits `turn_started` for the first battler.

2. **Each turn**  
   - BattleManager clears the battler’s flying/guard state and restores energy, then emits `turn_started(battler_index, is_party)`.  
   - BattleScene: dead battlers are skipped via `advance_turn()`.  
   - If **party**: shows the actions panel; the user picks a target (click, or Attack auto-picks a random valid enemy) and clicks Attack, Abilities, or End Turn.  
   - If **enemy**: hides actions, plays the turn intro, then `_run_enemy_turn()` and `advance_turn()`.

3. **advance_turn()**  
   - Emits `turn_ended` for the current battler.  
   - Increments `_current_turn_index`.  
   - If index is past the end of `_turn_order`:  
     - Calls `_check_battle_end()` (emits `battle_ended` if someone won) and stops if the battle is finished.  
     - Otherwise `_tick_round_effects()` (decrement shield and attack-buff durations for all battlers), then `_build_turn_order()`, reset index to 0, emit `turn_order_updated`.  
   - Emits `turn_started` for the next battler.

4. **Attack (player)**  
   - Target is `_selected_target`.  
   - On Attack: BattleScene plays the attacker’s slot animation (`play_attack_animation()`, 0.75s), then `perform_attack(get_current_battler(), _selected_target)`; hit results drive floating text, hit flash and SFX; then `advance_turn()`.

5. **Between floors** (Meridian Spire)  
   - On **Ascend — next floor**, `MissionProgress.meridian_advance_floor()` runs, the party is restored (HP, energy, flying/guard/shield cleared) and `setup_battle` is called again with new enemies (+10 enemy HP and +2 attack per floor above 1; floor 3 is a single “Custodian Unit”).

## Data structures

- **BattlerStats** (Resource): `display_name`, `max_hp`, `current_hp`, `attack`, `defense`, `speed`, `is_party`, `is_ranged`, `max_energy`, `current_energy`, runtime state `is_flying`, `shield_amount`, `shield_rounds_left`, `guard_active`, `attack_buff_amount`, `attack_buff_rounds_left`. Methods include `take_damage(amount, ignore_defense)`, `heal`, `is_alive`, `get_attack_power`, `has_energy` / `spend_energy` / `restore_energy`, `apply_shield`, `apply_guard`, `apply_attack_buff`, `tick_shield_round`, `tick_buff_rounds`, `duplicate_stats()`.
- **HeroRoster** (RefCounted, static): per hero `id`, `display_name`, `role_label`, `role_color`, `enabled`, base stats, `portrait`, `abilities`, `barks`. `ACTIVE_PARTY_SIZE` is 3, `FULL_ROSTER_SIZE` is 5.
- **Turn order entry** (Dictionary): `{ "stats": BattlerStats, "index": int, "is_party": bool }`. The `index` is the position in the party or enemy array.
- **Current battler / target**: Same structure. BattleScene and BattleManager pass these dicts around (e.g. `get_current_battler()`, `perform_attack(attacker, target)`).

## Where it’s implemented

- **BattleManager** (`scripts/battle/battle_manager.gd`): `setup_battle`, `_build_turn_order`, `advance_turn`, `_tick_round_effects`, `perform_attack`, `perform_ability`, ability/target validation helpers, `_check_battle_end`, and all signals.
- **BattleScene** (`scripts/battle/battle_scene.gd`): `_on_turn_started`, `_run_enemy_turn`, `_on_attack_requested`, `_on_abilities_requested`, `_on_ability_selected`, `_on_end_turn_requested`, `_on_battle_ended`, `_on_next_floor_requested`, floor setup (`HeroRoster.build_party`, `_build_enemies`, `_apply_mission_floor_visuals`), the turn-order bar (current battler gets “► TURN:” in an amber panel), arena turn highlight, hero barks, battle log and floating combat text.
- **BattlerSlot** (`scripts/battle/battler_slot.gd`): `setup`, `set_attack_frames`, `play_attack_animation()`, `play_hit_flash()`, `play_enemy_turn_flash()`, `set_role_display()`, `set_turn_highlight(active)`, `refresh()` (HP, shield and energy bars; Flying/Shielded/Guarded labels; shield bubble).
- **HeroRoster** (`scripts/battle/hero_roster.gd`): hero data and `apply_to_stats()`.
- **ShieldBubble** (`scripts/battle/shield_bubble.gd`) and **FloatingCombatText** (`scripts/battle/floating_combat_text.gd`): visual effects.
- **BattlerStats** (`resources/battler_stats.gd`): damage, shield, guard, buff and energy state.

To add abilities, you would extend `ABILITY_COSTS` and `perform_ability` in BattleManager, add the id to a hero’s `abilities` in `HeroRoster`, and (if it needs a target or an attack animation) add it to `TARGETED_ABILITIES` and `ATTACK_ANIM_ABILITIES`.

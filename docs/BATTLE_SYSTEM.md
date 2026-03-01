# Battle System

How turns, turn order, and combat work.

## Rules

- **Sides**: 3 party (allies) vs 1–4 enemies.
- **Turn order**: Each round, every **alive** battler is ordered by **speed** (highest first). They act in that order. When everyone has acted once, the round ends and order is recalculated for the next round (so speed and deaths change who goes first).
- **Attack**: BattleManager computes a damage value and calls `target.take_damage(damage)`. The exact formula is in `battle_manager.perform_attack()` (attack vs defense) and `battler_stats.take_damage()` (how HP is reduced).
- **Win/lose**: When a round ends, if all party are dead → defeat; if all enemies are dead → victory. BattleManager emits `battle_ended(party_wins)`.

## Turn flow (in code)

1. **setup_battle(party, enemies)**  
   - Stores party and enemies, calls `_build_turn_order()`, sets `_current_turn_index = 0`, emits `turn_order_updated`, then emits `turn_started` for the first battler.

2. **Each turn**  
   - BattleScene receives `turn_started(battler_index, is_party)`.  
   - If **party**: shows the actions panel; user picks target and clicks Attack or End Turn.  
   - If **enemy**: hides actions, waits 0.8s, then `_ai_turn()` (attack first alive party member) and calls `advance_turn()`.

3. **advance_turn()**  
   - Emits `turn_ended` for the current battler.  
   - Increments `_current_turn_index`.  
   - If index is past the end of `_turn_order`:  
     - Calls `_check_battle_end()` (emits `battle_ended` if someone won).  
     - If battle not finished: `_build_turn_order()`, reset index to 0, emit `turn_order_updated`, then emit `turn_started` for the new first battler.  
   - Otherwise: emit `turn_started` for the next battler in the same round.

4. **Attack (player)**  
   - User selected target → `_selected_target`.  
   - On Attack: BattleScene plays the attacker’s slot animation (`play_attack_animation()`: larger sprite, attack texture, 0.75s), then `perform_attack(get_current_battler(), _selected_target)` → damage applied to target’s `BattlerStats`; then `advance_turn()`.

## Data structures

- **BattlerStats** (Resource): `display_name`, `max_hp`, `current_hp`, `attack`, `defense`, `speed`, `is_party`. Methods: `take_damage(amount)`, `heal(amount)`, `is_alive()`, `duplicate_stats()`.
- **Turn order entry** (Dictionary): `{ "stats": BattlerStats, "index": int, "is_party": bool }`. The `index` is the position in the party or enemy array (0–3 for party, 0–n for enemies).
- **Current battler / target**: Same structure. BattleScene and BattleManager pass these dicts around (e.g. `get_current_battler()`, `perform_attack(attacker, target)`).

## Where it’s implemented

- **BattleManager** (`scripts/battle/battle_manager.gd`): `setup_battle`, `_build_turn_order`, `advance_turn`, `perform_attack`, `_check_battle_end`, and all signals.
- **BattleScene** (`scripts/battle/battle_scene.gd`): `_on_turn_started`, `_ai_turn`, `_on_attack_pressed`, `_on_end_turn_pressed`, turn-order bar (current battler gets “► TURN:” in an amber panel), arena turn highlight (`set_turn_highlight` on the current battler’s slot), and the logic that shows/hides the action panel and runs the AI.
- **BattlerSlot** (`scripts/battle/battler_slot.gd`): `setup(stats, texture_idle, texture_attack)`, `play_attack_animation()` (0.75s, slightly larger sprite), `set_turn_highlight(active)` (amber border when it’s this character’s turn).
- **BattlerStats** (`resources/battler_stats.gd`): `take_damage`, `heal`, `is_alive`.

To add skills, items, or different targeting, you’d extend BattleManager (e.g. new methods or signals) and wire them in BattleScene the same way as Attack/End Turn.

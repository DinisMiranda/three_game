# Architecture

How the project is structured and how the main pieces connect.

## Overview

- **Data**: `BattlerStats` (Resource) holds one character’s stats (HP, attack, defense, speed, energy, plus runtime state such as shield, guard and attack buff). `HeroRoster` (RefCounted, static data) holds the hero roster: stats, abilities, role labels, portraits and barks.
- **Logic**: `BattleManager` (Node) owns party and enemies, builds turn order by speed, resolves attacks and abilities, and emits signals.
- **UI**: `BattleScene` (Control) owns the layout, creates `BattlerSlot` instances for each character, applies the sci-fi theme, runs the enemy AI, and reacts to BattleManager signals and button/clicks.
- **Story**: one Control scene per story step (`briefing_dialogue`, `world_map_select`, `meridian_epilogue`, `hideout_select`, `hideout_debrief`), each a script that changes scene when it finishes.
- **Cross-scene state**: three autoloads (below).

Inside a battle there is no separate “game state” object; the source of truth is the BattleManager’s arrays of `BattlerStats` and the current turn index. State that must survive scene changes (which floor, story outcome flags, chosen hideout) lives in the `MissionProgress` autoload.

## Autoloads

Registered in `project.godot`:

| Autoload | Script | Role |
|----------|--------|------|
| `MusicPlayer` | `scripts/audio/music_player.gd` | Background music. `play_menu()` / `play_battle()` are called from each scene’s `_ready()`. |
| `MissionProgress` | `scripts/autoload/mission_progress.gd` | Meridian Spire run state: active mission, current floor (1–3), floor backgrounds and titles, epilogue/hideout flags, `HIDEOUTS` data. Scenes read it to decide where to go next. |
| `BattleSfx` | `scripts/audio/battle_sfx.gd` | Procedurally generated tone SFX (`play_hit`, `play_crit`, `play_miss`, `play_absorb`, `play_bark`); no audio files. |

## Game flow (scene graph)

```
main_menu.tscn            ← run/main_scene; Start Battle
  └─ briefing_dialogue    (office → alley)
       └─ world_map_select   (Deploy on Meridian Spire → MissionProgress.start_meridian_spire())
            └─ battle_scene  (floors 1–3; "Ascend — next floor" re-sets up the same scene)
                 ├─ defeat / abort            → main_menu
                 └─ rooftop cleared (Continue) → meridian_epilogue
                      └─ hideout_select
                           └─ hideout_debrief → main_menu (MissionProgress.complete_meridian_story())
```

Scene changes use `get_tree().change_scene_to_file(...)`. Several story scenes guard their entry on `MissionProgress` flags and redirect to the main menu when opened out of order (`meridian_epilogue` needs `meridian_epilogue_pending`, `hideout_select` needs `hideout_select_ready`, `hideout_debrief` needs a selected hideout). `hideout_select` defers that redirect with `change_scene_to_file.call_deferred(...)` because it runs inside `_ready()`.

## Who creates what (battle)

```
Battle (battle_scene.tscn + battle_scene.gd)  ← loaded from the world map
  ├── Background (TextureRect; changed per floor), EnemyTurnFlash, FloatingTextLayer (CanvasLayer)
  ├── Margin (UI)
  │     └── VBox: FloorBanner, TurnOrderBar, ArenaRow (Party + Enemies + Stats), BottomRow (Actions + Log)
  ├── EndScreen (CanvasLayer)  ← victory/defeat overlay (Ascend / Continue / Back to Main Menu)
  ├── OptionsMenu (instanced in code from scenes/ui/options_menu.tscn)
  └── BattleManager (battle_manager.gd)  ← created in code, add_child
```

- **BattleScene** creates the **BattleManager** in `_ready()` and adds it as a child (for lifecycle only; it’s not a visible node).
- **BattleScene** creates all **BattlerSlot** instances in `_build_arena()`. Slots are **added to the tree first** (`add_child(slot)`), then `setup(stats, texture_idle, texture_attack)` is called so that `@onready` nodes (e.g. `TextureRect`) are ready and the correct idle texture applies immediately (party faces right, enemies face left). Per-hero and per-enemy attack frames are set with `set_attack_frames()`.
- **BattlerStats** for the party come from `HeroRoster.apply_to_stats()` in `_build_sample_party()`; enemies are built per floor in `_build_sample_enemies()`. Both are given to `battle_manager.setup_battle(party, enemies)` from `_start_sample_battle()`.
- When the battle ends, **BattleScene** shows **EndScreen**. Depending on `MissionProgress` it offers **Ascend — next floor** (re-runs `setup_battle` with a restored party and new enemies), **Continue** (rooftop cleared, goes to the epilogue) or **Back to Main Menu**.

## Signal flow

```
BattleManager emits:
  turn_order_updated(order)  → BattleScene rebuilds the turn bar labels
  turn_started(index, is_party) → BattleScene shows actions (if party) or runs the enemy turn intro + _ai_turn() (if enemy)
  turn_ended(...)           → connected, currently a no-op in the UI
  battle_ended(party_wins)  → BattleScene shows EndScreen

BattleScene calls BattleManager:
  setup_battle(party, enemies)
  get_current_battler()
  get_party() / get_enemies()
  perform_attack(attacker_dict, target_dict)
  perform_ability(attacker_dict, ability_id, target_dict)
  can_attack_target / can_use_ability / can_use_ability_on_target / has_valid_target_for_ability
  get_ability_cost / ability_needs_target / get_ability_hint
  advance_turn()
```

When the user clicks an enemy **BattlerSlot**, it emits `slot_clicked(slot_index, is_party)`. BattleScene’s `_on_enemy_slot_clicked` sets `_selected_target`. When the user presses **Attack**, BattleScene plays the attack animation, calls `battle_manager.perform_attack(current_battler, _selected_target)`, applies the recorded hit results (flash, floating text, SFX) then `advance_turn()`. Abilities follow the same path through `perform_ability`.

## Data flow

- **Party / enemies**: Arrays of `BattlerStats` inside BattleManager. BattleScene reads them via `get_party()` and `get_enemies()`.
- **Turn order**: Built inside BattleManager in `_build_turn_order()` (alive only, sorted by speed). BattleScene rebuilds the turn bar in `_on_turn_order_updated()` using the same logic (alive + sort by speed) so the bar matches the manager.
- **Current battler**: BattleManager’s `_current_turn_index` into `_turn_order`. Exposed as `get_current_battler()` returning a dict `{ "stats", "index", "is_party" }`.
- **Target**: BattleScene’s `_selected_target` dict, set when the user clicks an enemy slot. Cleared after an action or when a new turn starts.
- **Hit results**: `BattleManager.last_hit_results` (list of `{ target_index, is_party, damage, kind }`) and `last_hit_kind` are filled by `perform_attack`; BattleScene reads them in `_apply_hit_results()` to drive floating text, hit flashes and SFX.
- **Mission state**: `MissionProgress` is read by BattleScene (floor, banner, background, end-screen routing) and by the story scenes (guards and hideout data).

## Where styling lives

- **Sci-fi colors and panel styles**: Defined and applied in `battle_scene.gd` (`_COLOR_*` constants, `_apply_sci_fi_theme()`, `_make_btn_style()`). Also used when creating the turn-order chips and the party stats panel bars. The options menu, main menu and story scenes each style themselves in their own scripts.
- **BattlerSlot**: Applies its own panel, HP bar, shield bar (darker blue when shielded) and energy bar style in `_ready()`. It supports an idle texture and one or more attack frames; the battle scene passes party idle (face right), enemy idle (face left), and shared or per-character attack textures. When it’s a battler’s turn, BattleScene calls `set_turn_highlight(true)` on that slot (amber border). `play_attack_animation()` plays the attack frames for 0.75s. When a battler has an active shield, **ShieldBubble** (script `shield_bubble.gd`) draws a blue semi-transparent circle behind the sprite; **ShieldedLabel**, **GuardedLabel** and the shield bar segment (on top of the HP bar) show the state.
- **Combat text**: `FloatingCombatText` (`floating_combat_text.gd`, a Label with a static `spawn()`) creates short-lived damage numbers in the battle scene’s `FloatingTextLayer`.
- **Background**: The battle and menu backgrounds are textures. `sci_fi_background.gd` (gradient and grid drawn in `_draw()`) is no longer instanced by any scene; it is kept only with its unit test.

For more detail on the battle rules and turn flow, see [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md). For file-by-file description, see [FILE_REFERENCE.md](FILE_REFERENCE.md).

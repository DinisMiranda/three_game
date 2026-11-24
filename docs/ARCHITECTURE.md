# Architecture

How the project is structured and how the main pieces connect.

## Overview

- **Data**: `BattlerStats` (Resource) holds one character’s stats (HP, attack, defense, speed, energy, plus runtime state such as shield, guard and attack buff). Hero, enemy and floor data are Resources edited as `.tres` files: `HeroData` (`resources/heroes/`), `EnemyArchetype` (`resources/enemies/`) and `MissionData` / `FloorData` (`resources/missions/meridian_spire.tres`). `HeroRoster` and `EnemyRoster` (RefCounted, static) are thin loaders over explicit path lists (`HERO_PATHS`, `ARCHETYPE_PATHS`) and keep the dictionary-based getters.
- **Logic**: `BattleManager` (Node) owns party and enemies, builds turn order by speed, resolves attacks and abilities, and emits signals.
- **UI**: `BattleScene` (Control) is a thin controller. It creates the BattleManager and the battle components listed below, and connects their signals. Slots, panels, log lines, AI and the end screen each live in their own component.
- **Story**: one Control scene per story step (`briefing_dialogue`, `world_map_select`, `meridian_epilogue`, `hideout_select`, `hideout_debrief`), each a script that changes scene when it finishes.
- **Cross-scene state and transitions**: four autoloads (below).

Inside a battle there is no separate “game state” object; the source of truth is the BattleManager’s arrays of `BattlerStats` and the current turn index. State that must survive scene changes (which floor, story outcome flags, chosen hideout) lives in the `MissionProgress` autoload.

## Autoloads

Registered in `project.godot`:

| Autoload | Script | Role |
|----------|--------|------|
| `MusicPlayer` | `scripts/audio/music_player.gd` | Background music. `play_menu()` / `play_battle()` are called from each scene’s `_ready()`. |
| `MissionProgress` | `scripts/autoload/mission_progress.gd` | Meridian Spire run state: active mission, current floor (1–3), floor backgrounds, titles and enemy lineups (loaded from `resources/missions/meridian_spire.tres` into `MERIDIAN_FLOORS`), epilogue/hideout flags, `HIDEOUTS` data. Scenes read it to decide where to go next. |
| `BattleSfx` | `scripts/audio/battle_sfx.gd` | Procedurally generated tone SFX (`play_hit`, `play_crit`, `play_miss`, `play_absorb`, `play_bark`); no audio files. |
| `SceneFader` | `scenes/ui/scene_fader.tscn` (`scripts/autoload/scene_fader.gd`) | Fade-through-black: `change_scene(path)` and `fade_through(callable)`. Fade timings are exported on the scene. |
| `Telemetry` | `scripts/autoload/telemetry.gd` (`TelemetryService`) | Opt-in (default off), anonymous gameplay events. `track(name, payload)` builds the versioned envelope, validates against `EVENT_SCHEMAS`, and writes to a pluggable `TelemetrySink`. Registered first so other autoloads can use it. Contract: `docs/analytics/event-schema.md`. |

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

Scene changes use `SceneFader.change_scene(...)`, which wraps `get_tree().change_scene_to_file(...)` in a fade. Several story scenes guard their entry on `MissionProgress` flags and redirect to the main menu when opened out of order (`meridian_epilogue` needs `meridian_epilogue_pending`, `hideout_select` needs `hideout_select_ready`, `hideout_debrief` needs a selected hideout). These redirects run inside `_ready()`, so they are deferred with `SceneFader.change_scene.call_deferred(...)`.

## Who creates what (battle)

```
Battle (battle_scene.tscn + battle_scene.gd)  ← loaded from the world map
  ├── Background (TextureRect; changed per floor), EnemyTurnFlash, FloatingTextLayer (CanvasLayer)
  ├── Margin (UI)
  │     └── VBox: FloorBanner, TopBar (TurnOrderBar + SpeedBtn), ArenaRow (Party + Enemies), BottomRow (ActionsPanel [action_panel.gd] + Party status [party_status_panel.gd] + BattleLog)
  ├── EndScreen (CanvasLayer, battle_end_screen.gd)  ← victory/defeat overlay (Ascend / Continue / Back to Main Menu)
  ├── OptionsMenu (instanced in code from scenes/ui/options_menu.tscn)
  ├── BattleManager (battle_manager.gd)  ← created in code, add_child
  ├── BattleFx (battle_fx.gd)  ← created in code; combat presentation, tuned by BattleFeel
  ├── arena: ArenaView (arena_view.gd, RefCounted)  ← builds and owns the BattlerSlots and sprite textures
  ├── narrator: BattleNarrator (battle_narrator.gd, RefCounted)  ← every coloured log line
  └── _enemy_ai: EnemyAI (enemy_ai.gd, RefCounted)  ← enemy action and target choice
```

### Battle components

| Component | Owns | Talks to the controller through |
|---|---|---|
| `ActionPanel` | Attack / Abilities / End Turn buttons, the ability list and its swap with the main rows | signals `attack_requested`, `abilities_requested`, `ability_selected(id, name)`, `end_turn_requested`; calls `show_panel`, `set_enabled`, `open_abilities(entries)`, `close_abilities` |
| `ArenaView` | slot rows, hero and enemy textures, turn and target highlights, turn order entries | signal `enemy_slot_clicked`; calls `build`, `refresh`, `slot_for`, `highlight_turn`, `highlight_targets` |
| `PartyStatusPanel` | the Party status rows (HP and energy bars) | call `refresh(party, feel)` |
| `BattleNarrator` | log colours and every message text | calls `say`, `attack_result`, `hero_ability`, `enemy_ability`, `hero_bark` |
| `EnemyAI` | AI profile rules and party target choice (pure `choose_action`, unit tested) | calls `choose_for(attacker)`, `pick_target(attacker, id)` |
| `BattleEndScreen` | outcome title and buttons, spire clear bookkeeping | signals `next_floor_requested`, `back_to_menu_requested`; calls `show_outcome`, `close` |

Rule of thumb: signals go up (component to controller), calls go down (controller to component). Only `BattleScene` knows about `BattleManager`; components receive plain data (entries, arrays, dictionaries).

- **BattleScene** creates the **BattleManager** in `_ready()` and adds it as a child (for lifecycle only; it’s not a visible node).
- **BattleScene** (via **ArenaView.build()**) creates all **BattlerSlot** instances. Slots are **added to the tree first** (`add_child(slot)`), then `setup(stats, texture_idle, texture_attack)` is called so that `@onready` nodes (e.g. `TextureRect`) are ready and the correct idle texture applies immediately (party faces right, enemies face left). Per-hero and per-enemy attack frames are set with `set_attack_frames()`.
- **BattlerStats** for the party come from `HeroRoster.apply_to_stats()` in `_build_sample_party()`; enemies are built per floor in `_build_sample_enemies()` from the archetype ids in `MissionProgress.MERIDIAN_FLOORS` (built from the MissionData resource) via **EnemyRoster** (EnemyArchetype resources) (boss archetypes get the aura shader and info plate through `BattlerSlot.set_boss_visual()`). Both are given to `battle_manager.setup_battle(party, enemies)` from `_start_sample_battle()`.
- When the battle ends, **BattleScene** shows the **EndScreen** (`BattleEndScreen`). Depending on `MissionProgress` it offers **Ascend — next floor** (re-runs `setup_battle` with a restored party and new enemies inside `SceneFader.fade_through()`), **Continue** (rooftop cleared, goes to the epilogue) or **Back to Main Menu**.

## Signal flow

```
BattleManager emits:
  turn_order_updated(order)  → BattleScene feeds the turn bar from ArenaView.turn_order_entries()
  turn_started(index, is_party) → BattleScene shows ActionPanel (if party) or runs the enemy turn intro + _run_enemy_turn() (if enemy)
  turn_ended(...)           → connected, currently a no-op in the UI
  battle_ended(party_wins)  → BattleScene calls BattleEndScreen.show_outcome()

Player input path:
  ActionPanel.attack_requested / ability_selected / end_turn_requested → BattleScene → BattleManager
  ArenaView.enemy_slot_clicked → BattleScene sets the selected target
  BattleEndScreen.next_floor_requested / back_to_menu_requested → BattleScene (floor rebuild or scene change)

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

When the user clicks an enemy **BattlerSlot**, it emits `slot_clicked(slot_index, is_party)`. BattleScene’s `_on_enemy_slot_clicked` (fed by ArenaView's `enemy_slot_clicked` signal) sets `_selected_target`. When the user presses **Attack**, BattleScene plays the attack animation, calls `battle_manager.perform_attack(current_battler, _selected_target)`, applies the recorded hit results (flash, floating text, SFX) then `advance_turn()`. Abilities follow the same path through `perform_ability`.

## Data flow

- **Party / enemies**: Arrays of `BattlerStats` inside BattleManager. BattleScene reads them via `get_party()` and `get_enemies()`.
- **Turn order**: Built inside BattleManager in `_build_turn_order()` (alive only, sorted by speed). BattleScene rebuilds the turn bar in `_on_turn_order_updated()` (entries from `ArenaView.turn_order_entries()`) using the same logic (alive + sort by speed) so the bar matches the manager.
- **Current battler**: BattleManager’s `_current_turn_index` into `_turn_order`. Exposed as `get_current_battler()` returning a dict `{ "stats", "index", "is_party" }`.
- **Target**: BattleScene’s `_selected_target` dict, set when the user clicks an enemy slot. Cleared after an action or when a new turn starts.
- **Hit results**: `BattleManager.last_hit_results` (list of `{ target_index, is_party, damage, kind }`) and `last_hit_kind` are filled by `perform_attack`; BattleScene reads them in `_apply_hit_results()` to drive floating text, hit flashes and SFX.
- **Static data**: `.tres` -> `HeroData` / `EnemyArchetype` / `MissionData` -> loaded once by `HeroRoster` / `EnemyRoster` / `MissionProgress` -> `BattlerStats` (via `apply_to_stats`) and visual getters. No code holds balance numbers.
- **Mission state**: `MissionProgress` is read by BattleScene (floor, banner, background, end-screen routing) and by the story scenes (guards and hideout data).

## Telemetry data flow

```
MissionProgress ──mission_start / floor_reached / mission_end──┐
BattleManager ──battle_start / turn_start / action / battler_down /
                ability_unaffordable / battle_end────────────────┤
Telemetry (session_start / session_end) ─────────────────────────┤
                                                                  v
             TelemetryService.track()  -- opted out? no-op
                 | validate(EVENT_SCHEMAS) -- invalid? push_warning + drop
                 | build_envelope(): schema_version, event_id, event_seq, ts_utc,
                 |                   session_id, run_id, battle_id, source, ...
                 v
             TelemetrySink.write_event(event, json_line)
                 |-- TelemetryFileSink: buffered, user://telemetry/events_YYYY-MM-DD.jsonl,
                 |                      rotates at 5 MB; flushed on battle_end,
                 |                      scene change, 64 lines, quit
                 '-- TelemetryMemorySink: tests / in-process simulator
```

- **Seams, not UI.** Events come from BattleManager and MissionProgress, so the
  headless simulator produces identical rows by giving its own BattleManager a
  `TelemetryService` configured with `configure(sink, "sim", true)`.
- **Receiver resolution.** `BattleManager.telemetry` is injected (tests, sim) or
  resolved lazily from `/root/Telemetry`; with neither, instrumentation is silent.
- **Ids.** `BattlerStats.battler_id` = `HeroData.id` for heroes, `<enemy_type>_<slot>`
  for enemies (set by HeroRoster / EnemyRoster). `run_id` lives for one mission
  attempt, `battle_id` for one floor fight.
- **Determinism.** `BattleManager.rng` (optional) seeds crit rolls; its seed is
  logged in `battle_start.seed`.
- **Simulator.** `tools/sim/run_sim.gd` (CLI) -> `BattleSimulator` builds, per run,
  its own `BattleManager` and `MissionProgress` instance (both with `telemetry`
  injected), lets a `PartyPolicy` play the party and `EnemyAI` the enemies, and
  writes `source = "sim"` JSONL. `TelemetryService.use_virtual_clock()` makes
  durations (and, with `--deterministic-ids`, UUIDs and timestamps) seed-derived.
  See `docs/analytics/simulator.md`.
- **Opt-in** persists in `user://settings.cfg` `[telemetry] opt_in`, toggled
  from the Options menu.

## Where styling lives

- **Sci-fi colors and panel styles**: Panels and buttons come from the project Theme; `battle_scene.gd` wires runtime colours in `_apply_theme_colors()`, log colours live in `BattleNarrator`, and the party bars in `PartyStatusPanel`. Also used when creating the turn-order chips and the party stats panel bars. The options menu, main menu and story scenes each style themselves in their own scripts.
- **BattleFeel** (`battle_feel.gd`, `resources/battle_feel_default.tres`): every combat-feel timing plus the status bar colours (HP cyan / low / critical thresholds, energy yellow) and the bar tags. BattleScene passes it to BattleFx, TurnOrderBar and each BattlerSlot.
- **BattlerSlot**: Applies its own panel, HP bar (recoloured by HP ratio), shield bar and energy bar style in `_ready()`, each with a tag and a current/max number. It supports an idle texture and one or more attack frames; the battle scene passes party idle (face right), enemy idle (face left), and shared or per-character attack textures. When it’s a battler’s turn, BattleScene calls `set_turn_highlight(true)` on that slot (amber border). `play_attack_animation()` plays the attack frames (length from BattleFeel when called by BattleFx). When a battler has an active shield, **ShieldBubble** (script `shield_bubble.gd`) draws a blue semi-transparent circle behind the sprite; **ShieldedLabel**, **GuardedLabel** and the shield bar segment (on top of the HP bar) show the state.
- **Combat text**: `FloatingCombatText` (`floating_combat_text.gd`, a Label with a static `spawn()`) creates short-lived damage numbers in the battle scene’s `FloatingTextLayer`.
- **Background**: The battle and menu backgrounds are textures. The old procedural `sci_fi_background.gd` was removed in Phase 3.

For more detail on the battle rules and turn flow, see [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md). For file-by-file description, see [FILE_REFERENCE.md](FILE_REFERENCE.md).

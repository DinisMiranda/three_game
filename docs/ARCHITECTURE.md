# Architecture

How the project is structured and how the main pieces connect.

## Overview

- **Data**: `BattlerStats` (Resource) holds one character’s stats (HP, attack, defense, speed, etc.).
- **Logic**: `BattleManager` (Node) owns party and enemies, builds turn order by speed, resolves attacks, and emits signals.
- **UI**: `BattleScene` (Control) owns the layout, creates `BattlerSlot` instances for each character, applies the sci-fi theme, and reacts to BattleManager signals and button/clicks.

There is no separate “game state” object; the source of truth is the BattleManager’s arrays of `BattlerStats` and the current turn index.

## Who creates what

```
MainMenu (main_menu.tscn + main_menu.gd)  ← run/main_scene; "Start Battle" loads battle_scene
Battle (battle_scene.tscn + battle_scene.gd)  ← loaded from main menu
  ├── Background (TextureRect), MarginContainer (UI)
  │     └── VBox: TurnOrderBar, ArenaRow (Party + Enemies + Stats), BottomRow (Actions + Log)
  ├── EndScreen (CanvasLayer)  ← victory/defeat overlay; "Back to Main Menu" loads main_menu
  └── BattleManager (battle_manager.gd)  ← created in code, add_child
```

- The game starts at **MainMenu**; pressing **Start Battle** runs `change_scene_to_file("res://scenes/battle/battle_scene.tscn")`.
- **BattleScene** creates the **BattleManager** in `_ready()` and adds it as a child (for lifecycle only; it’s not a visible node).
- When the battle ends, **BattleScene** shows **EndScreen** (Victory/Defeat and **Back to Main Menu**); that button loads the main menu scene.
- **BattleScene** creates all **BattlerSlot** instances in `_build_arena()`. Slots are **added to the tree first** (`add_child(slot)`), then `setup(stats, texture_idle, texture_attack)` is called so that `@onready` nodes (e.g. `TextureRect`) are ready and the correct idle texture applies immediately (party faces right, enemies face left).
- **BattlerStats** are created in `_start_sample_battle()` and given to `battle_manager.setup_battle(party, enemies)`.

## Signal flow

```
BattleManager emits:
  turn_order_updated(order)  → BattleScene rebuilds the turn bar labels
  turn_started(index, is_party) → BattleScene shows actions (if party) or runs _ai_turn() (if enemy)
  turn_ended(...)           → (currently unused in UI)
  battle_ended(party_wins)  → BattleScene shows EndScreen (Victory/Defeat) with Back to Main Menu

BattleScene calls BattleManager:
  setup_battle(party, enemies)
  get_current_battler()
  get_party() / get_enemies()
  perform_attack(attacker_dict, target_dict)
  advance_turn()
```

When the user clicks an enemy **BattlerSlot**, it emits `slot_clicked(slot_index, is_party)`. BattleScene’s `_on_enemy_slot_clicked` sets `_selected_target`. When the user presses **Attack**, BattleScene calls `battle_manager.perform_attack(current_battler, _selected_target)` then `advance_turn()`.

## Data flow

- **Party / enemies**: Arrays of `BattlerStats` inside BattleManager. BattleScene never stores its own copy; it always reads via `get_party()` and `get_enemies()`.
- **Turn order**: Built inside BattleManager in `_build_turn_order()` (alive only, sorted by speed). BattleScene rebuilds the turn bar in `_on_turn_order_updated()` using the same logic (alive + sort by speed) so the bar matches the manager.
- **Current battler**: BattleManager’s `_current_turn_index` into `_turn_order`. Exposed as `get_current_battler()` returning a dict `{ "stats", "index", "is_party" }`.
- **Target**: BattleScene’s `_selected_target` dict, set when the user clicks an enemy slot. Cleared after an attack or when a new turn starts.

## Where styling lives

- **Sci-fi colors and panel styles**: Defined and applied in `battle_scene.gd` (`_COLOR_*` constants, `_apply_sci_fi_theme()`, `_make_btn_style()`). Also used when creating the turn-order chips and the party stats panel bars.
- **BattlerSlot**: Applies its own panel and HP bar style in `_ready()`. It supports two textures (idle and attack); the battle scene passes party idle (face right), enemy idle (face left), and a shared attack texture. When it's a battler's turn, BattleScene calls `set_turn_highlight(true)` on that slot (amber border). Attack animation temporarily uses a larger size and the attack texture for 0.75s.
- **Background**: Drawn in `sci_fi_background.gd`’s `_draw()` (gradient, grid, bottom line). No theme; just drawing.

For more detail on the battle rules and turn flow, see [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md). For file-by-file description, see [FILE_REFERENCE.md](FILE_REFERENCE.md).

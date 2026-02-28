# File Reference

What each important file does.

## Project root

| File | Purpose |
|------|--------|
| `project.godot` | Godot project config: app name, main scene (`scenes/main/main.tscn`), window size (1920×1080), stretch mode, input actions. |
| `README.md` | Short project description and how to run. |
| `LICENSE` | MIT license. |

## Resources

| File | Purpose |
|------|--------|
| `resources/battler_stats.gd` | **BattlerStats** (Resource). Holds one character’s stats: name, HP, attack, defense, speed, is_party. Methods: `take_damage`, `heal`, `is_alive`, `duplicate_stats`. Used by BattleManager and by the UI to show names/HP. |

## Scripts

### Main

| File | Purpose |
|------|--------|
| `scripts/main/main.gd` | Attached to the Main root. Entry point; battle is already a child in main.tscn, so `_ready()` doesn’t need to load anything. Comment explains how to switch to battle from a menu later. |

### Battle

| File | Purpose |
|------|--------|
| `scripts/battle/battle_manager.gd` | **BattleManager** (Node). Core battle logic: stores party and enemies, builds turn order by speed, `advance_turn`, `perform_attack`, win/lose. Emits: `turn_started`, `turn_ended`, `battle_ended`, `turn_order_updated`. No UI. |
| `scripts/battle/battle_scene.gd` | Attached to BattleScene root. Creates BattleManager, loads placeholder texture, applies sci-fi theme, starts sample battle, builds arena (party/enemy slots), wires signals to UI (turn bar, log, actions). Handles target selection (click enemy), Attack, End Turn, AI turn, Restart. |
| `scripts/battle/battler_slot.gd` | **BattlerSlot** (PanelContainer). One character slot: texture (with fallback if image missing), name label, HP bar. Applies sci-fi panel/bar style. Emits `slot_clicked(slot_index, is_party)` on click when alive. Used for both party and enemies (enemies get texture flipped). |
| `scripts/battle/sci_fi_background.gd` | Attached to SciFiBackground Control. Implements `_draw()`: dark gradient, grid lines, bottom accent line. No logic. |

## Scenes

| File | Purpose |
|------|--------|
| `scenes/main/main.tscn` | Root: Main (Control + main.gd). Child: Battle (instance of battle_scene.tscn). This is the main scene set in project.godot. |
| `scenes/battle/battle_scene.tscn` | Root: BattleScene (Control + battle_scene.gd). Children: SciFiBackground (Control + sci_fi_background.gd), MarginContainer with full UI (turn bar, PartyArena/EnemyArena with PartySlots/EnemySlots, PartyStatsPanel, BottomRow with ActionsPanel and LogPanel). Slot containers are empty at design time; battle_scene.gd fills them in `_build_arena()`. |
| `scenes/battle/battler_slot.tscn` | Root: BattlerSlot (PanelContainer + battler_slot.gd). Layout: HBox with TextureRect (sprite) and Info VBox (NameLabel, HPBar). |

## Assets

| File | Purpose |
|------|--------|
| `assets/character_placeholder.png` | Default sprite for all battlers. Party use it as-is; enemies use it with horizontal flip. If this fails to load, BattlerSlot shows a generated checker texture. |
| `assets/character_placeholder.png.import` | Godot import config for the PNG (e.g. texture type, compression). |

## Docs

| File | Purpose |
|------|--------|
| `docs/README.md` | Doc index and quick links. |
| `docs/ARCHITECTURE.md` | How scripts and scenes connect, who creates what, signal flow. |
| `docs/BATTLE_SYSTEM.md` | Turn order, round flow, attack formula, win/lose, data structures. |
| `docs/FILE_REFERENCE.md` | This file. |
| `docs/SCENES_AND_UI.md` | Scene tree and UI layout, formation, theme. |
| `docs/PLACEHOLDER_IMAGE.md` | Why the placeholder image might not show; the three load strategies and the fallback texture. |

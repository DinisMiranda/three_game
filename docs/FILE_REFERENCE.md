# File Reference

What each important file does.

## Project root

| File | Purpose |
|------|--------|
| `project.godot` | Godot project config: app name, main scene (`scenes/main_menu/main_menu.tscn`), window size (1920×1080), stretch mode, input actions, autoload `MusicPlayer`. |
| `README.md` | Short project description and how to run. |
| `LICENSE` | MIT license. |

## Resources

| File | Purpose |
|------|--------|
| `resources/battler_stats.gd` | **BattlerStats** (Resource). Holds one character’s stats: name, HP, attack, defense, speed, is_party. Methods: `take_damage`, `heal`, `is_alive`, `duplicate_stats`. Used by BattleManager and by the UI to show names/HP. |

## Scripts

### Audio

| File | Purpose |
|------|--------|
| `scripts/audio/music_player.gd` | **MusicPlayer** (autoload). Plays BGM: `play_menu()` (menu.ogg / background.ogg), `play_battle()` (battle.ogg / background.ogg). Loops OGG/MP3. Add files under `assets/music/`. |
| `scripts/ui/options_menu.gd` | Options overlay (CanvasLayer): volume slider (Master bus), Back to Main Menu, Quit, Close. ESC toggles; used in main menu and battle. |
| `scenes/ui/options_menu.tscn` | Options menu: overlay, panel with volume slider and buttons. Instanced by main_menu and battle_scene. |

### Main menu

| File | Purpose |
|------|--------|
| `scripts/main_menu/main_menu.gd` | Attached to MainMenu root. Shows title and **Start Battle** button; on press, `change_scene_to_file("res://scenes/battle/battle_scene.tscn")`. Calls `MusicPlayer.play_menu()`. Sci-fi theme. |
| `scenes/main_menu/main_menu.tscn` | Root: MainMenu (Control + main_menu.gd). Background ColorRect, Margin, VBox with Title and StartBtn. |

### Main (legacy)

| File | Purpose |
|------|--------|
| `scripts/main/main.gd` | Optional: attached to Main root in main.tscn. Previously the entry point; now the game starts from main_menu.tscn instead. |

### Battle

| File | Purpose |
|------|--------|
| `scripts/battle/battle_manager.gd` | **BattleManager** (Node). Core battle logic: stores party and enemies, builds turn order by speed, `advance_turn`, `perform_attack`, win/lose. Emits: `turn_started`, `turn_ended`, `battle_ended`, `turn_order_updated`. No UI. |
| `scripts/battle/battle_scene.gd` | Attached to BattleScene root. Creates BattleManager, loads three textures (party idle, enemy idle, attack), applies sci-fi theme, starts sample battle, builds arena (add_child then setup so textures apply). Rebuilds turn bar with “► TURN:” panel for current battler; highlights current slot with amber border. Handles target selection (click enemy), Attack (plays attack animation then damage), End Turn, AI turn. On battle end shows EndScreen (Victory/Defeat) with Back to Main Menu (loads main_menu.tscn). Sizes EndScreen overlay to viewport. |
| `scripts/battle/battler_slot.gd` | **BattlerSlot** (PanelContainer). One character slot: two textures (idle + attack), name label, HP bar. `setup(stats, texture_idle, texture_attack)`; `play_attack_animation()` shows attack sprite at larger size for 0.75s; `set_turn_highlight(active)` toggles amber border. `refresh()` hides the slot when the battler is dead (removed from display). Applies sci-fi panel/bar style. Emits `slot_clicked(slot_index, is_party)` on click when alive. Party and enemies use different idle textures (face right / face left). |
| `scripts/battle/sci_fi_background.gd` | Unused: previously drew gradient + grid on battle screen; battle now uses the background texture only. Kept in project for reference. |

## Scenes

| File | Purpose |
|------|--------|
| `scenes/main_menu/main_menu.tscn` | Root: MainMenu (Control + main_menu.gd). Entry scene (run/main_scene). Background, VBox with Title and StartBtn. Instances options menu; ESC opens it. |
| `scenes/main/main.tscn` | Optional: Main (Control + main.gd) with Battle as child. No longer the run/main_scene; game starts from main menu. |
| `scenes/battle/battle_scene.tscn` | Root: BattleScene (Control + battle_scene.gd). Children: Background (TextureRect), MarginContainer with full UI (turn bar, arena, BottomRow with ActionsPanel and LogPanel), EndScreen (CanvasLayer). Slot containers are empty at design time; battle_scene.gd fills them in `_build_arena()`. |
| `scenes/battle/battler_slot.tscn` | Root: BattlerSlot (PanelContainer + battler_slot.gd). Layout: HBox with TextureRect (sprite) and Info VBox (NameLabel, HPBar). |

## Assets

| File | Purpose |
|------|--------|
| `assets/character_placeholder.png` | Fallback sprite if Sevro assets fail to load. |
| `assets/sevro_pixel_no_bg.png` | Hero 1 idle (face right). |
| `assets/hero 2 no bg.png` | Hero 2 idle (face right). |
| `assets/hero 3 no bg.png` | Hero 3 idle (face right). |
| `assets/enemy_1-removebg-preview.png` | Enemy 1 idle (face left). |
| `assets/enemy_2-removebg-preview.png` | Enemy 2 idle (face left). |
| `assets/sevro_atack_no_bg.png` | Enemy attack sprite (face left). |
| `assets/sevro_atack_no_bg_1-removebg-preview.png` | Party attack sprite (face right). |
| `assets/e32ee0a6-a11a-4f0a-b8be-ec9723487b2b.png` | Shared fullscreen background image (main menu and battle scene; stretch keep aspect covered). |
| `assets/music/` | Folder for BGM: **menu.ogg**, **battle.ogg**, or single **background.ogg** (see `assets/music/README.md`). |
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

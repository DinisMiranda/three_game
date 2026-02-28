# Three Game — Documentation

This folder explains how the project is built and how each part works.

## Quick links

| Doc | What it covers |
|-----|-----------------|
| [**ARCHITECTURE.md**](ARCHITECTURE.md) | How the project is structured; scripts and scenes; signal flow |
| [**BATTLE_SYSTEM.md**](BATTLE_SYSTEM.md) | Turn order, round flow, attack resolution, data structures |
| [**FILE_REFERENCE.md**](FILE_REFERENCE.md) | Every important file and what it does |
| [**SCENES_AND_UI.md**](SCENES_AND_UI.md) | Scene tree, UI layout, sci-fi theme |
| [**PLACEHOLDER_IMAGE.md**](PLACEHOLDER_IMAGE.md) | Why the character image might not show; load strategies and fallback |
| [**cursor-playbooks/README.md**](cursor-playbooks/README.md) | Cursor AI playbooks (request, refresh, retro) and how to use them |

## Run the game

1. Open the project in Godot (folder containing `project.godot`).
2. Press **F5** (or click Play). The main scene loads and goes straight into battle.

## High-level flow

1. **Main menu** (`scenes/main_menu/main_menu.tscn`) is the entry scene; **Start Battle** loads the battle scene.
2. **Battle** (`scenes/battle/battle_scene.tscn`) creates a **BattleManager** (logic) and builds the arena from **BattlerSlot** instances (party left, enemies right). Dead battlers are hidden (slots set not visible).
3. **BattleManager** decides turn order by **speed** each round and emits signals; the battle scene listens and updates the UI (turn bar, slots, log, actions).
4. On **player turn**: you click an enemy to target, then **Attack** or **End Turn**. On **enemy turn**: a simple AI attacks the first alive party member after a short delay.
5. When the battle ends, an **end screen** appears (Victory! or Defeat!) with **Back to Main Menu** to return to the main menu.

For more detail, use the links above.

## Keeping docs in sync

When you change battle logic, UI, or add features, update the relevant docs so they stay accurate:

- **ARCHITECTURE.md** — who creates what, signal flow, where styling lives
- **BATTLE_SYSTEM.md** — turn flow, attack resolution, where it’s implemented
- **SCENES_AND_UI.md** — scene tree, BattlerSlot layout, theme and turn bar
- **FILE_REFERENCE.md** — purpose of each script, scene, and asset

Use **English** for all documentation and in-code comments.

# Three Game — Documentation

This folder explains how the project is built and how each part works.

## Quick links

| Doc | What it covers |
|-----|-----------------|
| [**ARCHITECTURE.md**](ARCHITECTURE.md) | How the project is structured; autoloads, scripts and scenes; game flow; signal flow |
| [**BATTLE_SYSTEM.md**](BATTLE_SYSTEM.md) | Turn order, round flow, abilities, damage resolution, enemy AI, data structures |
| [**FILE_REFERENCE.md**](FILE_REFERENCE.md) | Every important file and what it does |
| [**SCENES_AND_UI.md**](SCENES_AND_UI.md) | Scene trees (menu, battle, story, options), UI layout, sci-fi theme |
| [**PLACEHOLDER_IMAGE.md**](PLACEHOLDER_IMAGE.md) | Why the character image might not show; load strategies and fallback |
| [**BETA_PLAY.md**](BETA_PLAY.md) | Beta build: download links, install steps for macOS and Windows |
| [**design/portfolio-plan.md**](design/portfolio-plan.md) | Portfolio plan: combat polish, telemetry, data pipeline and data-driven rebalance |
| [**cursor-playbooks/README.md**](cursor-playbooks/README.md) | Cursor AI playbooks (request, refresh, retro) and how to use them |

## Run the game

1. Open the project in Godot 4.7 (folder containing `project.godot`).
2. Press **F5** (or click Play). The main menu loads; **Start Battle** starts the story.

## High-level flow

1. **Main menu** (`scenes/main_menu/main_menu.tscn`) is the entry scene (`run/main_scene`). **Start Battle** fades out and loads the briefing; **Options** opens the options overlay (ESC also opens it).
2. **Briefing** (`scenes/story/briefing_dialogue.tscn`): typewriter dialogue in two phases (office, then alley). ESC skips the current phase. It ends on the **world map**.
3. **World map** (`scenes/story/world_map_select.tscn`): pan the tactical map, click zones, the squad marker walks to the zone. Only **Meridian Spire** is unlocked; **Deploy** calls `MissionProgress.start_meridian_spire()` and loads the battle.
4. **Battle** (`scenes/battle/battle_scene.tscn`) creates a **BattleManager** (logic) and builds the arena from **BattlerSlot** instances (party left, enemies right). The Meridian Spire run has **3 floors**; clearing a floor offers **Ascend — next floor** (party is restored), and each floor sets its own background and enemies.
5. **BattleManager** decides turn order by **speed** each round and emits signals; the battle scene listens and updates the UI (turn bar, slots, log, floating combat text, actions).
6. On **player turn**: click an enemy to target, then **Attack**, **Abilities** (each hero has two, costing energy) or **End Turn**. On **enemy turn**: a short flash intro, then an AI picks an attack or ability by enemy profile.
7. When the battle ends, an **end screen** appears. After the rooftop (floor 3) victory, **Continue** loads the **epilogue**; on defeat it returns to the main menu.
8. **Epilogue** (`meridian_epilogue`) → **Hideout select** (`hideout_select`, three hideouts) → **Hideout debrief** (`hideout_debrief`, Brick and Sage) → main menu.

For more detail, use the links above.

## Keeping docs in sync

When you change battle logic, UI, or add features, update the relevant docs so they stay accurate:

- **ARCHITECTURE.md** — who creates what, autoloads, game flow, signal flow, where styling lives
- **BATTLE_SYSTEM.md** — turn flow, abilities, attack resolution, enemy AI, where it’s implemented
- **SCENES_AND_UI.md** — scene trees, BattlerSlot layout, theme and turn bar, story scenes
- **FILE_REFERENCE.md** — purpose of each script, scene, and asset

Use **English** for all documentation and in-code comments.

# Three Game — Turn-based battle (Godot 4)

A **4 vs 1–4** turn-based battle game. Turn order is determined by **character speed** (higher speed acts first each round).

## Requirements

- **Godot 4.3** (or 4.x; adjust `config/features` in `project.godot` if needed)

## How to run

1. Open the project in Godot (open the folder containing `project.godot`).
2. Press **F5** or click **Run Project**. The main scene loads and starts a sample battle.

## How it works

- **Party**: 4 characters (fixed).
- **Enemies**: 1–4 (random in the sample battle).
- **Turn order**: At the start of each round, all alive party members and enemies are sorted by **speed** (descending). They act in that order. When everyone has acted, a new round starts and order is recalculated.
- **On your turn**: Select an enemy in the list, then click **Attack** (or **End Turn** to skip).
- **Enemy turns**: Enemies take a simple AI turn (attack first alive party member) after a short delay.

## Project layout

- `resources/battler_stats.gd` — Stats resource (HP, attack, defense, **speed**, etc.).
- `scripts/battle/battle_manager.gd` — Turn order by speed, round flow, attack resolution.
- `scripts/battle/battle_scene.gd` — Battle UI, input, sample battle setup.
- `scenes/main/main.tscn` — Entry scene (loads battle).
- `scenes/battle/battle_scene.tscn` — Battle UI scene.

You can extend this with more actions, skills, or a main menu that starts the battle.

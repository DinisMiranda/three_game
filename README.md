# Three Game

> Turn-based tactical battler (Godot 4.7, GDScript): a 3-hero squad climbs a three-floor mission, with a tactical world map, story scenes, hero abilities and speed-based turn order. Sci-fi style UI.

[![CI](https://github.com/DinisMiranda/three_game/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/DinisMiranda/three_game/actions/workflows/ci-cd.yml)
[![codecov](https://codecov.io/gh/DinisMiranda/three_game/graph/badge.svg)](https://codecov.io/gh/DinisMiranda/three_game)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`godot` `godot4` `turn-based` `battle` `gdscript`

## Repository structure

```
.
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── roadmap.mkd
├── project.godot
├── .github/           # CI, beta release workflow, Dependabot, CODEOWNERS, issue/PR templates
│   └── workflows/     # ci-cd.yml (branch flow, docs lint + link check, Godot validate, tests), beta-release.yml
├── addons/gdUnit4/    # Unit-test framework
├── assets/            # Sprites, backgrounds, map, shaders, music
├── build/             # export_presets.cfg (beta exports)
├── docs/              # Project documentation (see docs/README.md)
│   └── design/        # Portfolio plan
├── resources/         # BattlerStats
├── scenes/            # main_menu, battle, story, ui (plus legacy main)
├── scripts/           # audio, autoload, battle, main_menu, story, ui, coverage helpers
└── tests/             # 45 gdUnit4 tests in 8 suites
```

## How to run

1. Open the project in **Godot 4.7** (folder containing `project.godot`).
2. Press **F5** or click **Run Project**. The main menu loads; **Start Battle** begins the story.

**Requirements:** Godot 4.7.x (`config/features` in `project.godot` is `4.7`; CI and the beta exports use 4.7.2).

**Tests:** `./run_tests.sh` (or `run_tests.cmd` on Windows); see [tests/README.md](tests/README.md).

## How it works

- **Game flow:** Main menu → briefing dialogue (office, then alley) → tactical world map (only *Meridian Spire* is playable) → three battle floors → epilogue (rooftop, office, base) → hideout select → squad debrief with Brick and Sage → main menu. Defeat returns to the main menu.
- **Party:** 3 heroes (Kael, Nova, Rin), each with a role and two abilities. Brick and Sage exist in the roster but only appear in story scenes. **Enemies:** 1–2 per floor, each with a small AI profile.
- **Turn order:** Each round, all alive battlers are sorted by **speed** (higher first). When everyone has acted, order is recalculated.
- **Your turn:** Click an enemy to target (or let Attack pick one) → **Attack**, **Abilities** (cost energy) or **End Turn**. Hits can crit (15%) or be absorbed by shields; results show as floating combat text and log lines.
- **Systems:** `BattleManager` (rules), `BattleScene` (UI and AI), `HeroRoster` (hero data), `MissionProgress` (autoload tracking mission and story state), `MusicPlayer` and `BattleSfx` (audio autoloads).

## Documentation

| Area        | Docs |
|------------|------|
| Overview   | [docs/README.md](docs/README.md) — index and quick links |
| Architecture | [ARCHITECTURE.md](docs/ARCHITECTURE.md) — scripts, scenes, autoloads, signals, game flow |
| Battle     | [BATTLE_SYSTEM.md](docs/BATTLE_SYSTEM.md) — turn order, abilities, damage, enemy AI, data |
| Files      | [FILE_REFERENCE.md](docs/FILE_REFERENCE.md) — what each file does |
| UI         | [SCENES_AND_UI.md](docs/SCENES_AND_UI.md) — scene trees, layout, theme, story scenes |
| Placeholder image | [PLACEHOLDER_IMAGE.md](docs/PLACEHOLDER_IMAGE.md) — why it might not show, load strategies |
| Beta build | [BETA_PLAY.md](docs/BETA_PLAY.md) — download and install the playtest build |

Full index: [docs/README.md](docs/README.md).

## Roadmap

See [docs/design/portfolio-plan.md](docs/design/portfolio-plan.md) for the portfolio plan (combat polish, telemetry, data pipeline and data-driven rebalance).

## Credits

Art was generated with ChatGPT and edited by the author; fonts are Exo 2 (OFL) and Roboto Mono (Apache 2.0). Full list with licences: [CREDITS.md](CREDITS.md).

## More information

- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute (issues, PRs, Conventional Commits).
- [SECURITY.md](SECURITY.md) — how to report security issues.
- [CHANGELOG.md](CHANGELOG.md) — notable changes by version.

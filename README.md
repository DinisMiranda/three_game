# Three Game

> Turn-based battle game (Godot 4): 3 heroes vs 1–4 enemies, turn order by speed. Sci-fi style UI.

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
├── .gitignore
├── project.godot
├── .github/           # CODEOWNERS, issue/PR templates
├── assets/            # Sprites, placeholder image
├── docs/              # Project documentation
│   ├── README.md      # Doc index
│   ├── ARCHITECTURE.md
│   ├── BATTLE_SYSTEM.md
│   ├── FILE_REFERENCE.md
│   ├── SCENES_AND_UI.md
│   └── PLACEHOLDER_IMAGE.md
├── resources/         # BattlerStats, etc.
├── scenes/            # main, battle, battler_slot
└── scripts/           # battle, main
```

## How to run

1. Open the project in **Godot 4.x** (folder containing `project.godot`).
2. Press **F5** or click **Run Project**. The main scene loads and starts a sample battle.

**Requirements:** Godot 4.3+ (adjust `config/features` in `project.godot` if needed).

## How it works

- **Party:** 3 heroes (left), each with a different sprite. **Enemy:** 1 (right) for now. Formation: two rows (">" and "<").
- **Turn order:** Each round, all alive battlers are sorted by **speed** (higher first). When everyone has acted, order is recalculated.
- **Your turn:** Click an enemy to target → **Attack** or **End Turn**. **Enemy turn:** Simple AI attacks first alive party member.

## Documentation

| Area        | Docs |
|------------|------|
| Overview   | [docs/README.md](docs/README.md) — index and quick links |
| Architecture | [ARCHITECTURE.md](docs/ARCHITECTURE.md) — scripts, scenes, signals |
| Battle     | [BATTLE_SYSTEM.md](docs/BATTLE_SYSTEM.md) — turn order, combat, data |
| Files      | [FILE_REFERENCE.md](docs/FILE_REFERENCE.md) — what each file does |
| UI         | [SCENES_AND_UI.md](docs/SCENES_AND_UI.md) — scene tree, layout, theme |
| Placeholder image | [PLACEHOLDER_IMAGE.md](docs/PLACEHOLDER_IMAGE.md) — why it might not show, load strategies |

Full index: [docs/README.md](docs/README.md).

## Cursor AI (optional)

Project uses the [Autonomous Principal Engineer](https://gist.github.com/aashari/07cc9c1b6c0debbeb4f4d94a3a81339e) prompting framework:

- **Doctrine** is in [.cursor/rules/](.cursor/rules/) and applies automatically (research-first, trust code over docs, etc.).
- **Playbooks** (request, refresh, retro) live in [docs/cursor-playbooks/](docs/cursor-playbooks/) — copy into chat when starting a task. See [docs/cursor-playbooks/README.md](docs/cursor-playbooks/README.md).

## More information

- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute (issues, PRs, Conventional Commits).
- [SECURITY.md](SECURITY.md) — how to report security issues.
- [CHANGELOG.md](CHANGELOG.md) — notable changes by version.

# Unit tests

Unit tests use [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4). The addon is already in `addons/gdUnit4` and enabled in the project.

## Running locally

### Option A — Command line (from project root)

**macOS / Linux** (or WSL, Git Bash on Windows):

```bash
./run_tests.sh
```

**Windows** (Command Prompt or PowerShell):

```cmd
run_tests.cmd
```

If Godot is not in `PATH`, set `GODOT_BIN` first:

- **macOS:** `export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot`
- **Linux:** `export GODOT_BIN=/usr/bin/godot` (or your Godot path)
- **Windows:** `set GODOT_BIN=C:\Path\To\Godot.exe`

### Option B — Inside Godot editor

1. Open the project in Godot 4.x (the GdUnit4 plugin is already enabled).
2. Open the **GdUnit4** panel (top-left) and use the run buttons, or right-click the `tests/` folder in the FileSystem and choose **Run GdUnit4 Tests**.

## Viewing results

- **Command line (`./run_tests.sh`):** The terminal shows a live summary (passed/failed counts, which tests ran). At the end you get total suites, test cases, time, and an exit code (0 = success).
- **HTML report:** After a run, GdUnit4 writes a report into the **`reports/`** folder in the project root. Open `reports/gdUnit4_report_<number>/index.html` in a browser for a full report (each test, duration, failures). The terminal also prints a line like `Open Report at: file:///path/to/reports/...`.
- **In the editor:** When you run tests from the GdUnit4 panel, the results appear in that panel (green/red, expandable per test).

## CI

The **Unit tests** job in `.github/workflows/ci-cd.yml` runs on every push/PR to develop, staging, and main. It installs GdUnit4 and Godot 4.6 and runs all tests under `tests/`.

## Test files

| File | Covers |
|------|--------|
| `test_battler_stats.gd` | `BattlerStats`: take_damage, heal, shield, energy, duplicate_stats |
| `test_battle_manager.gd` | `BattleManager`: get_ability_cost, can_use_ability, can_attack_target, setup_battle, perform_attack, perform_ability, advance_turn, battle_ended |
| `test_shield_bubble.gd` | `ShieldBubble`: instantiate and draw |
| `test_sci_fi_background.gd` | `SciFiBackground`: instantiate and draw |
| `test_music_player.gd` | `MusicPlayer`: play_menu, play_battle, stop, set_volume_db |
| `test_main.gd` | Main entry script: _ready |
| `test_battler_slot.gd` | `BattlerSlot` (scene): setup, refresh, set_turn_highlight |
| `test_battle_scene.gd` | `BattleScene` (scene): battle_manager present and sample battle setup |

## Coverage summary

**Coverage:** When you run `./run_tests.sh` or `run_tests.cmd`, a **coverage summary** is printed at the end (estimated % of game script lines that have unit tests). **Target: 80%+** (currently ~85%).

**Covered scripts:** BattlerStats, BattleManager, ShieldBubble, SciFiBackground, BattlerSlot, BattleScene, MusicPlayer, main.

**Not covered:** main_menu, options_menu (UI-heavy; suited for integration or manual testing).

## Exit warnings (CLI)

When you run tests from the command line (`./run_tests.sh`), Godot may print at exit:

- **"ObjectDB instances leaked"** / **"N resources still in use at exit"**

These are common when the engine shuts down after running a script (e.g. GdUnit4 with `-s`). They do **not** mean tests failed. They come from the engine’s teardown and from resources (scenes, scripts, textures) loaded during the run. Exit code 0 and the test summary are what matter for success.

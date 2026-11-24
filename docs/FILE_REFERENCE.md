# File Reference

What each file does. Godot sidecar files (`*.import`, `*.uid`) sit next to their source files and are not listed separately. The `addons/gdUnit4/` test framework and the agent tooling under `.claude/` are third-party/tooling and are not described here; `docs/engine-reference/` and `docs/cursor-playbooks/` are reference material.

## Project root

| File | Purpose |
|------|--------|
| `project.godot` | Godot project config: app name, main scene (`scenes/main_menu/main_menu.tscn`), `4.7` feature tag, window size (1920×1080), stretch mode, input actions, autoloads `MusicPlayer`, `MissionProgress`, `BattleSfx`, and the gdUnit4 plugin. |
| `README.md` | Project description, structure, how to run, how it works. |
| `CHANGELOG.md` | Notable changes by version. |
| `CONTRIBUTING.md` | How to contribute (issues, PRs, Conventional Commits, CI). |
| `SECURITY.md` | How to report security issues. |
| `LICENSE` | MIT license. |
| `roadmap.mkd` | Project roadmap notes. |
| `export_presets.cfg.example` | Example Godot export presets. |
| `build/export_presets.cfg` | Export presets used by the beta release workflow. |
| `run_tests.sh` / `run_tests.cmd` | Run the gdUnit4 suite from the command line (macOS/Linux and Windows). |
| `.gitignore` | Git ignore rules. |
| `.markdownlint.yaml` | Markdown lint rules used by CI. |
| `lychee.toml` / `.lycheeignore` | Link-check configuration and ignore list. |

## GitHub

| File | Purpose |
|------|--------|
| `.github/workflows/ci-cd.yml` | **Validate & Deploy**: branch-flow check, docs lint and link check, headless Godot validate, gdUnit4 tests with coverage upload, staging/production deploy jobs. Uses Godot 4.7.2. |
| `.github/workflows/beta-release.yml` | **Beta Release**: on `v*-beta*` tags, exports macOS and Windows builds and publishes a GitHub release. |
| `.github/workflows/README.md` | Branch flow and workflow overview. |
| `.github/CODEOWNERS` | Code owners. |
| `.github/dependabot.yml` | Dependabot config for GitHub Actions. |
| `.github/PULL_REQUEST_TEMPLATE.md` | Pull request template. |
| `.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md`, `config.yml` | Issue templates and issue chooser config. |

## Resources

| File | Purpose |
|------|--------|
| `resources/battler_stats.gd` | **BattlerStats** (Resource). One character’s stats: name, HP, attack, defense, speed, is_party, is_ranged, energy, plus runtime state (flying, shield, guard, attack buff). Methods: `take_damage` (guard halves, shield absorbs, then defense), `heal`, `is_alive`, `get_attack_power`, energy helpers, `apply_shield`, `apply_guard`, `apply_attack_buff`, `tick_shield_round`, `tick_buff_rounds`, `duplicate_stats`. |
| `resources/heroes/*.tres` | One **HeroData** per hero (kael, nova, rin; reserved brick, sage): stats, abilities, barks, portrait, shader grade. Balance edits go here. |
| `resources/enemies/*.tres` | One **EnemyArchetype** per enemy type (warden, hound, custodian, enforcer): base stats, per-floor scaling, AI profile, sprites, tint / aura, boss flag. |
| `resources/missions/meridian_spire.tres` | **MissionData** for Meridian Spire: three **FloorData** sub-resources (title, background, enemy type ids). |

## Scripts

### Audio

| File | Purpose |
|------|--------|
| `scripts/audio/music_player.gd` | **MusicPlayer** (autoload). `play_menu()` (`menu.*` or `background.*`), `play_battle()` (`battle.*` or `background.*`), `stop()`, `set_volume_db()`. Loops OGG/MP3 from `assets/music/`. |
| `scripts/audio/battle_sfx.gd` | **BattleSfx** (autoload). Generates short sine-tone SFX in code: hit, crit, miss, absorb, bark. |

### Autoload

| File | Purpose |
|------|--------|
| `scripts/autoload/telemetry.gd` | **Telemetry** (autoload, `class_name TelemetryService`). Opt-in anonymous event tracking: envelope, `EVENT_SCHEMAS` validation, opt-in persistence (`user://settings.cfg`), `begin_run`/`begin_battle` ids, `configure(sink, source, opted_in)` for tests and the simulator. |
| `scripts/autoload/mission_progress.gd` | **MissionProgress** (autoload). Emits `mission_start`, `floor_reached`, `mission_end` telemetry. Meridian Spire run state (active mission, floor 1–3; floor titles, backgrounds and lineups loaded from `resources/missions/meridian_spire.tres`), epilogue and hideout flags, `HIDEOUTS` data, and helpers such as `start_meridian_spire`, `meridian_advance_floor`, `mark_rooftop_cleared`, `mark_hideout_select_ready`, `select_hideout`, `complete_meridian_story`. |

### Telemetry

| File | Purpose |
|------|--------|
| `scripts/telemetry/telemetry_sink.gd` | `TelemetrySink` base: `write_event(event, line)`, `flush()`, `close()`. |
| `scripts/telemetry/file_sink.gd` | `TelemetryFileSink`: buffered JSONL to `<dir>/<prefix>_YYYY-MM-DD.jsonl`, rotates over 5 MB. |
| `scripts/telemetry/memory_sink.gd` | `TelemetryMemorySink`: keeps events in memory (tests, simulator); `names()`, `of(name)`. |

### Main menu and options

| File | Purpose |
|------|--------|
| `scripts/main_menu/main_menu.gd` | MainMenu root. Title, **Start Battle** (fade, then `briefing_dialogue.tscn`), **Options**, concept panel, intro animation, repeating background shader. Calls `MusicPlayer.play_menu()`. |
| `scripts/ui/options_menu.gd` | Options overlay (CanvasLayer): Master volume slider, telemetry opt-in toggle (Telemetry.set_opted_in), Back to Main Menu, Quit, Close. ESC toggles; used in the main menu and battle. |

### Main (legacy)

| File | Purpose |
|------|--------|
| `scripts/main/main.gd` | Legacy entry script for `main.tscn` (battle as a child). Its `_ready()` does nothing; the game starts from the main menu. |

### Story

| File | Purpose |
|------|---------|
| `scripts/story/briefing_dialogue.gd` | Pre-battle briefing: office phase (Handler, Nova) then alley phase (Nova, Kael), typewriter text, ESC skips a phase, then fades to the world map. |
| `scripts/story/world_map_select.gd` | Tactical map: drag/arrow-key panning, clickable zones (only Meridian Spire is unlocked), marker walks to the chosen zone, **Deploy** starts the mission and loads the battle. |
| `scripts/story/map_zone.gd` | **MapZone** (Control). Clickable zone overlay with hover/selected highlight; emits `zone_clicked(zone_id)`. |
| `scripts/story/map_player_marker.gd` | Draws the squad position marker on the map. |
| `scripts/story/meridian_epilogue.gd` | Post-rooftop story in three phases (rooftop, office, base); then `mark_hideout_select_ready()` and loads hideout select. Redirects to the main menu if the epilogue is not pending. |
| `scripts/story/hideout_select.gd` | Builds one card per hideout from `MissionProgress.HIDEOUTS`, stores the choice, loads the debrief. Redirects (deferred) to the main menu if not ready. |
| `scripts/story/hideout_debrief.gd` | Dialogue at the chosen hideout with Brick and Sage; ends with `complete_meridian_story()` and the main menu. |

### Battle

| File | Purpose |
|------|--------|
| `scripts/battle/battle_manager.gd` | **BattleManager** (Node). Party/enemy storage, turn order by speed, `advance_turn`, energy restore, `perform_attack` (crit, defense, hit recording), `perform_ability` and ability costs/validation, round-end effect ticks, win/lose check. Signals: `turn_started`, `turn_ended`, `battle_ended`, `turn_order_updated`. No UI. |
| `scripts/battle/battle_scene.gd` | BattleScene controller (~480 lines). Creates BattleManager and the components below, connects their signals, runs the turn flow (player actions, enemy turn, hit results) and floor progression. |
| `scripts/battle/action_panel.gd` | ActionPanel: Attack / Abilities / End Turn buttons and the ability list; emits request signals. |
| `scripts/battle/arena_view.gd` | ArenaView (RefCounted): builds the party and enemy slot rows, owns sprite textures, turn and target highlights, turn order entries. |
| `scripts/battle/party_status_panel.gd` | PartyStatusPanel: the Party status HP / energy rows. |
| `scripts/battle/battle_narrator.gd` | BattleNarrator (RefCounted): coloured log lines, attack and ability messages, hero barks. |
| `scripts/battle/enemy_ai.gd` | EnemyAI (RefCounted): AI profile action choice (pure, unit tested) and party target choice. |
| `scripts/battle/battle_end_screen.gd` | BattleEndScreen: victory / defeat overlay and its buttons. |
| `scripts/battle/battler_slot.gd` | **BattlerSlot** (PanelContainer). One character slot: name, role, status labels, HP/shield/energy bars, sprite with attack frames. `setup`, `set_attack_frames`, `play_attack_animation`, `play_hit_flash`, `play_enemy_turn_flash`, `set_role_display`, `set_turn_highlight`, `refresh`. Emits `slot_clicked(slot_index, is_party)`. |
| `scripts/battle/hero_roster.gd` | **HeroRoster** (static loader). Loads the five HeroData files in `HERO_PATHS` (Kael, Nova, Rin active; Brick, Sage reserved); `get_hero`, `get_data`, `apply_to_stats`, `build_party`, `find_index_by_name`, portrait lookups for story scenes. |
| `scripts/battle/hero_data.gd` | **HeroData** (Resource). Typed, grouped, documented fields for one hero; `to_dict()`, `get_shader_grade()`. |
| `scripts/battle/enemy_roster.gd` | **EnemyRoster** (static loader). Loads the EnemyArchetype files in `ARCHETYPE_PATHS`; `get_archetype`, `get_data`, stat / visual getters, `build_display_names`, `build_enemies`. |
| `scripts/battle/enemy_archetype.gd` | **EnemyArchetype** (Resource). Typed fields for one enemy type; `get_max_hp(floor)`, `get_attack(floor)`, `get_aura_color()`, `to_dict()`. |
| `scripts/missions/mission_data.gd`, `scripts/missions/floor_data.gd` | **MissionData** (id, name, floors) and **FloorData** (title, background, enemies; `to_dict()`). |
| `scripts/battle/floating_combat_text.gd` | **FloatingCombatText** (Label). Static `spawn()` creates a rising, fading damage/status number. |
| `scripts/battle/shield_bubble.gd` | **ShieldBubble** (Control). Draws a blue semi-transparent circle when visible. |

### Coverage helpers

| File | Purpose |
|------|--------|
| `scripts/print_coverage.sh` / `scripts/print_coverage.py` | Print a coverage estimate after a test run. |
| `scripts/generate_coverage_xml.py` | Generates a Cobertura XML coverage report for CI. |

## Scenes

| File | Purpose |
|------|--------|
| `scenes/main_menu/main_menu.tscn` | Entry scene (`run/main_scene`). Background, Margin/ContentRow with MenuColumn (Title, Subtitle, StartBtn, OptionsBtn) and ConceptPanel. |
| `scenes/story/briefing_dialogue.tscn` | Briefing UI: office background, tint, MercSide and BossSide portraits and dialogue panels, hint, fade overlay. |
| `scenes/story/world_map_select.tscn` | Tactical map: HUD title, scrolling map canvas (map, zones layer, player marker), info panel and Deploy button. |
| `scenes/story/map_zone.tscn` | Root for a MapZone (Control + `map_zone.gd`). |
| `scenes/battle/battle_scene.tscn` | BattleScene: Background, EnemyTurnFlash, FloatingTextLayer, Margin/VBox (FloorBanner, TurnOrderBar, ArenaRow, BottomRow with ActionsPanel and LogPanel), EndScreen. Slot containers are empty at design time; `ArenaView.build()` fills them. ActionsPanel, StatsList and EndScreen carry component scripts. |
| `scenes/battle/battler_slot.tscn` | BattlerSlot: NameLabel, RoleLabel, Flying/Shielded/Guarded labels, HPBarContainer (HPBar, ShieldBar), EnergyBar, SpriteContainer (ShieldBubble, TextureRect). |
| `scenes/story/meridian_epilogue.tscn` | Epilogue dialogue UI (same layout as the briefing, plus BagProp). |
| `scenes/story/hideout_select.tscn` | Hideout selection: header, cards row, footer with RallyBtn, hint, fade overlay. |
| `scenes/story/hideout_debrief.tscn` | Debrief dialogue UI with a LocationBanner. |
| `scenes/ui/options_menu.tscn` | Options overlay: panel with volume slider, TelemetryToggle (CheckButton) + TelemetryHint, and Back/Quit/Close buttons. |
| `scenes/main/main.tscn` | Legacy: Main (Control + `main.gd`) with the battle scene as child. Not part of the game flow. |

## Assets

Heroes and enemies:

| File | Purpose |
|------|--------|
| `assets/character_placeholder.png` | Fallback sprite when another texture fails to load; portrait for the reserved heroes Brick and Sage. |
| `assets/sevro_pixel_no_bg-removebg-preview.png` | Kael idle / portrait (face right). |
| `assets/hero 2 no bg.png` | Nova idle / portrait (face right). |
| `assets/hero 3 no bg copy.png` | Rin idle / portrait (face right). |
| `assets/sevro_atack_no_bg_1-removebg-preview.png` | Shared party attack sprite (face right). |
| `assets/hero2_attack_animation.png` | Nova attack frame. |
| `assets/hero3_attack-removebg copy.png` | Rin attack frame. |
| `assets/enemy_1-removebg-preview.png` | Enemy 1 idle (face left); also the “Custodian”/“Helicopter” story portrait. |
| `assets/enemy_1_attack_animantion_part1-removebg-preview.png`, `assets/enemy1_attack_animation_part2-removebg-preview.png` | Enemy 1 two-frame attack animation. |
| `assets/enemy_2-removebg-preview.png` | Enemy 2 idle (face left). |
| `assets/enemy_2_attack_animation.png` | Enemy 2 attack frame. |
| `assets/enemy_2-removebg-preview copy.png` | Idle texture for the third enemy slot. |
| `assets/inimigo_soldado.png`, `assets/inimigo_soldado_ataque.png` | Soldier enemy (fourth slot) idle and attack sprite. |
| `assets/sevro_atack_no_bg.png` | Default enemy attack sprite (face left). |
| `assets/mission guy.png` | Handler portrait (briefing and story). |

Backgrounds, map and shaders:

| File | Purpose |
|------|--------|
| `assets/andar.jpg` | Corridor background for floors 1 and 2 and the default battle background. |
| `assets/e32ee0a6-a11a-4f0a-b8be-ec9723487b2b.png` | Rooftop / skyline background (floor 3 and epilogue). |
| `assets/escritorio.png` | Office background (briefing, epilogue; docks hideout). |
| `assets/alley.png` | Alley background (briefing, epilogue base; Rust Alley hideout). |
| `assets/background_blue.png` | Main menu background; North Grid hideout. |
| `assets/mapa.png` | Tactical world map image. |

Music:

| File | Purpose |
|------|--------|
| `assets/music/background.mp3` | Single track used for menu and battle (fallback name). |
| `assets/music/README.md` | Which file names `MusicPlayer` looks for (`menu.*`, `battle.*`, `background.*`). |

## Tests

| File | Purpose |
|------|--------|
| `tests/README.md` | How to run the tests, CI notes, test file table. |
| `tests/test_battler_stats.gd` | BattlerStats (12 tests). |
| `tests/test_battle_manager.gd` | BattleManager (21 tests). |
| `tests/test_telemetry.gd` | Telemetry envelope, schema validation, opt-out, JSONL file sink and rotation, BattleManager event sequence (17 tests). |
| `tests/test_battler_slot.gd` | BattlerSlot (3 tests). |
| `tests/test_battle_scene.gd` | BattleScene (wiring). |
| `tests/test_roster_resources.gd` | Phase 3B data resources: every .tres loads, roster getters return the pinned pre-3B values, floor lineups (11 tests). |
| `tests/test_enemy_ai.gd` | EnemyAI profiles and target choice (11 tests). |
| `tests/test_action_panel.gd` | ActionPanel signals and ability list (6 tests). |
| `tests/test_music_player.gd` | MusicPlayer (4 tests). |
| `tests/test_shield_bubble.gd` | ShieldBubble (1 test). |
| `tests/test_main.gd` | Main script (1 test). |

## Docs

| File | Purpose |
|------|--------|
| `docs/README.md` | Doc index and quick links. |
| `docs/ARCHITECTURE.md` | How scripts and scenes connect, autoloads, game flow, signal flow. |
| `docs/BATTLE_SYSTEM.md` | Turn order, round flow, abilities, damage, enemy AI, data structures. |
| `docs/FILE_REFERENCE.md` | This file. |
| `docs/SCENES_AND_UI.md` | Scene trees, UI layout, formation, story scenes, theme. |
| `docs/PLACEHOLDER_IMAGE.md` | Why the placeholder image might not show; the load strategies and fallback texture. |
| `docs/BETA_PLAY.md` | Beta build download links and install steps. |
| `docs/analytics/event-schema.md` | Telemetry event schema v1: envelope, per-event payloads, ids, mart mapping, privacy. |
| `docs/design/portfolio-plan.md` | Portfolio plan: combat polish, telemetry, data pipeline, rebalance. |

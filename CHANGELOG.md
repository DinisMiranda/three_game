# Changelog

Notable changes in this project. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added

- **Story flow** — Typewriter briefing dialogue (office, then alley) with phase-by-phase ESC skip; tactical world map (pan, zones, deploy); Meridian Epilogue; hideout select; hideout debrief with Brick and Sage.
- **Meridian Spire mission** — Three-floor run tracked by the `MissionProgress` autoload, with per-floor backgrounds, floor banner, party restore between floors and end-screen routing to the epilogue.
- **Hero roster and abilities** — `HeroRoster` with Kael, Nova and Rin active (Brick and Sage reserved); new abilities (Focus, Frenzy), enemy AI profiles, energy, crits.
- **Combat polish** — Floating combat text, hit flashes, enemy turn flash, hero barks, per-character attack frames, soldier enemy sprite; procedural `BattleSfx` autoload.
- **Beta pipeline** — macOS and Windows beta release workflow (`beta-release.yml`) and `docs/BETA_PLAY.md`.
- **Docs** — Portfolio plan (`docs/design/portfolio-plan.md`) and a refresh of README, ARCHITECTURE, BATTLE_SYSTEM, SCENES_AND_UI, FILE_REFERENCE to match the code.

### Changed

- **Godot 4.6 → 4.7.2** — CI images (godot-ci 4.7.2), gdUnit4 action, beta export templates, `config/features` and the README badge. Verified locally: clean headless import, 45/45 gdUnit4 tests, all scripts parse.
- **Dependencies** — markdownlint-cli2-action 22 → 23, codecov-action 5 → 6, gdUnit4-action bump.

### Fixed

- **hideout_select** — Footer and header node paths now include the `VBox` the script skipped, and the not-ready guard defers its scene change (`change_scene_to_file.call_deferred`) so it no longer runs while the tree is still adding children.
- **Battle stability** — Fixed an attack-spam softlock, floor progression startup and background safety issues.

---

## [0.2.0] — 2026-03-03

### Added

- **CI (GitHub Actions)** — Workflow runs on push/PR to `main`:
  - **Docs:** Markdown lint (markdownlint-cli2 + `.markdownlint.yaml`) and link check (Lychee). 429/timeout/connection do not fail the job.
  - **Godot:** Headless project validation (load and quit) with Godot 4.6.
- **Dependabot** — Monthly updates for GitHub Actions; commit prefix `chore(deps)`, grouping for minor/patch.
- **CONTRIBUTING** — Section on CI and how to run markdown lint locally.

### Changed

- **Issue config** — `blank_issues_enabled: false` (use a template); added link to docs index.
- **Pull request template** — Checklist for CI and Conventional Commits.
- **README** — CI badge and repository structure (workflows, Dependabot).

---

## [0.1.0] — 2025-02-28

### Added

- Turn-based battle: 4 party vs 1–4 enemies, turn order by speed (Godot 4).
- Battle UI: turn order bar, party/enemy slots in "> <" formation, party status panel, actions (Attack / End Turn), battle log.
- Sci-fi theme: dark gradient + grid background, cyan accents, styled panels and buttons.
- BattlerStats resource; BattleManager (logic) and BattleScene (UI); BattlerSlot with placeholder image (scene default + load fallbacks).
- Window 1920×1080; placeholder character image in scene so it loads reliably.
- Documentation: `docs/` (architecture, battle system, file reference, scenes/UI, placeholder image). Inline comments in scripts.
- Repo polish: `.gitignore`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/` (CODEOWNERS, issue/PR templates).

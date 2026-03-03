# Changelog

Notable changes in this project. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added

- (Future changes go here.)

---

## [0.2.0] — 2025-03-03

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

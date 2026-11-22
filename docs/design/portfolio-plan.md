# Triad Protocol: Portfolio Plan

**Date:** 2026-11-22 · **Branch:** `feat/portfolio-polish`

## Intent

Make Triad Protocol the main project on my CV, something I can show and talk through
in a recruiter interview. It has to work for two career paths:

- **Game developer:** a polished, readable, good-feeling turn-based battler with clean code.
- **Data analyst / data engineer:** the game collects gameplay telemetry, a data pipeline
  turns it into a dashboard, and the data drives real balance changes.

The interview story: *"I built the game, instrumented it, collected playtest and simulation
data, found balance problems in the data, fixed them, and measured the result."*

## Goals

1. **The first 3 minutes are polished.** Menu → map → briefing → first battle should feel
   finished: coherent look, impactful combat, no dead space, no errors.
2. **Playable in one click.** A web build on itch.io, linked from the CV and the README.
3. **The repo reads well.** README with GIF, up-to-date docs, split-up battle code,
   tests that pass in CI, `main` up to date.
4. **A complete data loop.** Telemetry → pipeline → dashboard → rebalance → before/after write-up.

## Non-goals

- New missions, campaign length, save/load, or extra heroes (the roster's 2 reserved slots stay reserved).
- A full 3D → sprite art pipeline (the roadmap's option A); too long for the value it adds here.
- Multiplayer, monetisation, mobile.

## Anti-goals (would be a failure even if it "works")

- Telemetry that collects personal data or runs without the player opting in.
- A dashboard full of vanity charts that no balance decision came from.
- Polish that breaks existing tests or the beta release pipeline.

## Constraints

- Godot **4.6**, GDScript, gdUnit4 tests (45 passing), GitHub Actions CI and beta exports.
- **The web export needs the Compatibility renderer.** The project currently uses
  Forward Plus, so the menu and map shaders must be checked under Compatibility.
- Low disk space: no long video captures, and clean up build artefacts.
- Small, frequent commits, pushed after every meaningful change.

## Approaches considered

| Approach | Trade-off | Verdict |
|---|---|---|
| **A. Game polish only** | Strongest for game-dev roles, says nothing to data roles | Rejected |
| **B. Separate data project** (e.g. a public dataset) | Clean data story, but splits my time and loses "my own game" | Rejected |
| **C. Game + built-in telemetry + pipeline** | Most work, but one project serves both careers with one coherent story | **Chosen** |

## Phases

Each phase ends playable, with tests green, committed, and pushed.

### Phase 0: Housekeeping
- Fix the `hideout_select` errors (`Layout/Footer/SelectedTitle`, `RallyBtn` not found;
  `remove_child` while the parent is busy).
- Bring the docs up to date with the real game (map, story scenes, roster, abilities).
- Merge the current work into `main` so the public default branch shows the real game.

### Phase 1: Combat feel and pacing
- Attack: the attacker lunges toward the target, then hit-stop (~60 ms), light screen shake,
  floating damage numbers (crits bigger and coloured), and a hit flash on the target.
- Death: fade/dissolve plus a slump; the turn bar removes the dead battler with an animation.
- Turn order bar: portraits/chips with side colours instead of `P Rin P Kael E Enemy 1`.
- Real enemy names (e.g. "Spire Sentinel"), consistent sprite scale, a readable energy bar.
- A compact battle log that collapses to the last 3 lines; the space goes back to the arena.
- Pacing: shorter fixed waits, a battle speed toggle (1×/2×), and fade transitions between scenes.

### Phase 2: Visual coherence
- One Godot `Theme` resource replaces the colours and styles set in code across all screens.
- One font family (the briefing's monospace becomes an accent only).
- Main menu: the empty "About" panel becomes a hero/mission teaser; "Start Battle" becomes "Continue / New Mission".
- Tactical map: replace the flat grey bars with the shared panel style; add zone hover states.
- Unified character treatment (outline / rim light shader) so the mixed-source sprites read as one cast.

### Phase 3: Code structure
- Split `battle_scene.gd` (1109 lines) into components: `TurnOrderBar`, `ActionPanel`,
  `BattleLog`, `BattleFx`, plus a thin scene controller.
- Move hero and enemy data from dictionaries to `.tres` Resources (the balance changes in phase 6 then become data edits).
- Keep and extend the tests; update ARCHITECTURE.md.

### Phase 4: Telemetry
- `Telemetry` autoload with a versioned event schema: `session_start`, `battle_start`,
  `turn_start`, `action` (actor, ability, target, damage, crit), `battler_down`,
  `battle_end` (result, turns, duration), `floor_reached`, `quit`.
- Anonymous session ID; **opt-in** toggle in Options; events written as JSONL to `user://telemetry/`.
- Upload of opted-in events from the web build to a free hosted Postgres (Supabase) through `HTTPRequest`.
- **Headless simulation runner:** the AI plays thousands of battles with the same events,
  which gives a large dataset even with few human playtesters.

### Phase 5: Data pipeline and dashboard (Python, in `analytics/`)
- Ingest JSONL / Postgres → **DuckDB**.
- SQL models, layered: `staging` (cleaned events) → `marts` (`fct_battles`, `fct_actions`,
  `dim_battlers`, mission funnel).
- Data-quality checks (schema, nulls, impossible values) run in CI.
- Dashboard (Streamlit): win rate by floor, damage share per hero, ability usage,
  turns per battle, mission funnel / drop-off.

### Phase 6: Data-driven rebalance and release
- Find 2–3 concrete balance issues in the data, change the Resources, re-run the simulation, and record before/after.
- Write the case study (`docs/case-study.md` plus a README section with charts).
- Web export to itch.io, README GIF, final merge to `main`.

## Decided

- Approach C; Godot 4.6 / GDScript for the game; Python + DuckDB + SQL + Streamlit for data.
- Order: Phase 0 → 1 → 2 → 3 → 4 → 5 → 6. Phases 1–2 come first because they are what a recruiter sees.

## Left to the builder

- Exact tween timings, shake strength and colours (tuned by eye in captures).
- Component boundaries inside `battle_scene.gd`.
- Supabase table layout, and whether the dashboard ships as Streamlit Cloud or a static export.

## Art direction (decided)

- Keep the current sci-fi style and **unify** it (outline / rim light shader, shared palette, consistent scale).
- Where a **free art pack** has better animations (attack, hit, death), use it for those characters
  or effects instead of the static sprites, as long as its licence allows it and it fits the palette.
- Credit every third-party asset in `CREDITS.md`, and label placeholder art honestly in the README.

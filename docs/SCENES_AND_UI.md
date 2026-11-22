# Scenes and UI

Scene trees and how the UI is laid out and styled.

## Scene overview

The game starts at **MainMenu** (`scenes/main_menu/main_menu.tscn`, `run/main_scene`). Scenes live under `scenes/`:

| Scene | Script | Role |
|-------|--------|------|
| `main_menu/main_menu.tscn` | `scripts/main_menu/main_menu.gd` | Title, **Start Battle**, **Options**, concept panel. |
| `story/briefing_dialogue.tscn` | `scripts/story/briefing_dialogue.gd` | Office and alley briefing dialogue. |
| `story/world_map_select.tscn` | `scripts/story/world_map_select.gd` | Tactical map; zones are `story/map_zone.tscn` instances. |
| `battle/battle_scene.tscn` | `scripts/battle/battle_scene.gd` | The battle. Slots are `battle/battler_slot.tscn`. |
| `story/meridian_epilogue.tscn` | `scripts/story/meridian_epilogue.gd` | Post-rooftop story (rooftop, office, base). |
| `story/hideout_select.tscn` | `scripts/story/hideout_select.gd` | Pick one of three hideouts. |
| `story/hideout_debrief.tscn` | `scripts/story/hideout_debrief.gd` | Squad debrief with Brick and Sage. |
| `ui/options_menu.tscn` | `scripts/ui/options_menu.gd` | Options overlay, instanced by the main menu and the battle. |
| `ui/scene_fader.tscn` | `scripts/autoload/scene_fader.gd` | `SceneFader` autoload: fade-through-black used for every scene change. |
| `main/main.tscn` | `scripts/main/main.gd` | Legacy: Main Control with the battle instanced as a child; not used by the game flow. |

Flow: Main menu → briefing → world map → battle (3 floors) → epilogue → hideout select → debrief → main menu. See [ARCHITECTURE.md](ARCHITECTURE.md).

Every step goes through **SceneFader** (`SceneFader.change_scene(path)`): fade to black, `change_scene_to_file`, wait one frame, fade back in. The battle's “next floor” uses `SceneFader.fade_through(callable)` to rebuild the same scene while the screen is black. Timings are exported on `scenes/ui/scene_fader.tscn` (`fade_out_duration` 0.4 s, `fade_in_duration` 0.45 s). While a fade runs the overlay blocks the mouse and further requests are refused.

## Main menu tree

```
MainMenu (Control, main_menu.gd)
  ├── Background (TextureRect; background_blue.png, repeated by menu_bg_repeat.gdshader)
  └── Margin (MarginContainer)
        └── ContentRow (HBoxContainer)
              ├── MenuColumn: Title, Subtitle, Spacer, StartBtn, OptionsBtn
              ├── RightSpacer
              └── ConceptPanel (PanelContainer: ConceptTitle, ConceptText)
```

**Start Battle** loads `briefing_dialogue.tscn` through SceneFader. ESC (or **Options**) shows the options overlay, instanced in code.

## Battle scene tree

```
BattleScene (Control, battle_scene.gd)
  ├── Background (TextureRect; texture swapped per floor)
  ├── EnemyTurnFlash (ColorRect; red flash on enemy turns)
  ├── FloatingTextLayer (CanvasLayer; damage / MISS / ABSORB numbers)
  ├── Margin (MarginContainer)
  │     └── VBox (VBoxContainer)
  │           ├── FloorBanner (Label; "MERIDIAN SPIRE · Floor N — ...", hidden outside the mission)
  │           ├── TopBar (PanelContainer)
  │           │     └── TopHBox: TurnOrderLabel "TURN ORDER", TurnOrderBar (turn_order_bar.gd; portrait chips), SpeedBtn ("1x" / "2x")
  │           ├── ArenaRow (HBoxContainer)
  │           │     ├── PartyArena: PartyLabel "Party (3)", PartySlots (VBoxContainer)
  │           │     └── EnemyArena: EnemyLabel "Enemy", EnemySlots (VBoxContainer)
  │           └── BottomRow (HBoxContainer)
  │                 ├── ActionsPanel (PanelContainer)
  │                 │     └── ActionsVBox
  │                 │           ├── Buttons (HBoxContainer: AttackBtn, AbilitiesBtn)
  │                 │           ├── EndTurnRow (HBoxContainer: EndTurnBtn)
  │                 │           └── AbilitySubPanel (VBoxContainer: AbilityLabel, AbilityButtonsContainer, AbilityBackBtn)
  │                 ├── PartyStatsPanel (PanelContainer) → StatsVBox: StatsTitle "Party status", StatsList (per hero: name, HP bar + "92/92", EN bar + "100/100")
  │                 └── LogPanel (PanelContainer, battle_log.gd; compact log, newest 3 lines, "History" toggle opens the full history above it)
  └── EndScreen (CanvasLayer; visible when battle ends)
        ├── Overlay (ColorRect; sized to the viewport in code)
        └── Center (CenterContainer)
              └── Panel (PanelContainer) → VBox: EndTitle, NextFloorBtn ("Ascend — next floor"), BackToMenuBtn
```

BattleManager, BattleFx and the options menu are **not** in the scene file; they are created in code in `battle_scene.gd` and added as children.

- **TurnOrderBar** (`turn_order_bar.gd`): BattleScene feeds it entries with `set_order(entries, active_key)`; it owns the chips, fades out a downed battler's chip and pops the active one.
- **SpeedBtn**: cycles `BattleFeel.speed_multipliers` (1x / 2x) through BattleFx.
- **BattleLog** (`battle_log.gd`): compact view plus a `top_level` history overlay, so opening it never reflows the layout.
- **PartyStatsPanel**: rebuilt by `_refresh_party_stats_panel()`. HP and energy use the same BattleFeel colours as the arena slots.
- **BattleFx** (`battle_fx.gd`) plays lunge, hit-stop, shake, hit flash, floating text and the death slump. Its timings, and the status bar colours, come from the **BattleFeel** resource (`resources/battle_feel_default.tres`, exported as `battle_feel` on BattleScene).

End screen titles: “Victory!”, “Floor clear!” (with NextFloorBtn, back button reads “Abort to menu”), “Rooftop secured!” (back button reads “Continue” and goes to the epilogue), “Meridian Spire secured!”, “Defeat!”.

## Arena formation

- **Party (left)**: One row of three slots, visual order Nova, Kael, Rin (Kael, party index 0, is in the middle).
- **Enemies (right)**: Two rows pushed right by a spacer. Enemy indices 0 and 1 are in the front row; 2 and 3, if present, in an indented back row. The Meridian Spire floors use one or two enemies.

Rows are built in `_build_arena()` with `_make_row(container, behind, add_leading_spacer, top_margin)`. When `behind == true`, the row is wrapped in a MarginContainer with `margin_left = 28`. Enemy slots are set up with a larger sprite size (380×494).

Enemies come from **EnemyRoster** (`enemy_roster.gd`): each floor lists archetype ids and the roster gives name, sprites, stats, `sprite_scale`, tint and boss flag. The boss (Custodian Unit, floor 3) gets `set_boss_visual(true)`: the `boss_aura.gdshader` glow, a 1.2× sprite scaled up from its feet, and a dark info plate behind its name and bars.

## BattlerSlot layout

```
BattlerSlot (PanelContainer, battler_slot.gd)
  └── VBox (VBoxContainer)
        ├── InfoPlate (PanelContainer; empty style, dark plate with aura-coloured border for the boss)
        │     └── Info (VBoxContainer)
        │           ├── NameLabel, RoleLabel, FlyingLabel, ShieldedLabel, GuardedLabel
        │           ├── HPRow: HPTag "HP", HPBarContainer (HPBar + ShieldBar overlapping), HPValue "80/100"
        │           └── EnergyRow: EnergyTag "EN", EnergyBar, EnergyValue "60/100"
        └── SpriteContainer (Control; sprite area, moved up when flying)
              ├── ShieldBubble (Control + shield_bubble.gd; blue semi-transparent circle when shielded)
              └── TextureRect (sprite; 200×260 idle by default, 1.2× during attack; keep aspect centered)
```

Slots are instanced from `scenes/battle/battler_slot.tscn`. BattleScene adds each slot to the tree first, then calls `setup(stats, texture_idle, texture_attack, size_override)`. `play_attack_animation()` cycles the attack frames over `BattleFeel.attack_anim_duration` (scaled by battle speed) with a small scale pulse. `play_hit_flash()` tints the sprite red; `play_enemy_turn_flash()` tints the whole slot. HP is cyan, then orange at or below 50% and red at or below 25%; energy is yellow (BattleFeel “Status Bars”). A dead battler's slot stays in place, dimmed by BattleFx, and `refresh()` hides its bars and numbers.

## Story scenes

The briefing, epilogue and debrief share one layout: a full-screen background texture (`SceneBackground` or `OfficeBackground`) plus a dark tint (`Background` ColorRect), a portrait and dialogue panel on each side (`MercSide`, `BossSide`), a `Hint` label and a `FadeOverlay`. Lines are revealed with a typewriter effect (48 characters/second); click, SPACE or Enter advances (finishing the typing first). **ESC skips** the current phase in the briefing and epilogue, and to the end in the debrief.

- **briefing_dialogue**: phases OFFICE (Handler and Nova) then ALLEY (Nova and Kael), then fade to the world map.
- **world_map_select**: `Layout` VBox with `HudTop` (Kicker, Title), a horizontally scrolling `MapScroll` → `MapCanvas` (`MapBg` using `mapa.png`, `ZonesLayer` with `MapZone` instances, `PlayerMarker`), and a `Hud` with `InfoPanel` (ZoneTitle, ZoneSubtitle), `DeployBtn` and a hint. Drag with the mouse or use the arrow keys to pan; Enter deploys. Zones: Meridian Spire (unlocked), North Grid, Central Archive, South Docks (locked).
- **meridian_epilogue**: phases ROOFTOP, OFFICE, BASE, plus a `BagProp` label; ends at `hideout_select`.
- **hideout_select**: `Layout` → `Header/VBox` (Kicker, Title, Subtitle), `CardsWrap/CardsRow` (one card per entry of `MissionProgress.HIDEOUTS`), `Footer/VBox` (SelectedTitle, SelectedSubtitle, RallyBtn), `Hint`. The script’s node paths include the `VBox` nodes under Header and Footer.
- **hideout_debrief**: same dialogue layout plus a `LocationBanner`, background taken from the chosen hideout.

## Options menu

`OptionsMenu` (CanvasLayer, `options_menu.gd`): `Overlay` ColorRect and a centered `Panel` with a Title, a `VolumeRow` (slider mapped from −40 dB to 0 dB on the Master bus, percentage label), **Back** (to main menu), **Quit** and **Close**. ESC opens it from the main menu and the battle and closes it again.

## Sci-fi theme (colors and styles)

Applied in `battle_scene.gd` (`_apply_sci_fi_theme()` and related):

- **Panels**: Dark background (`_COLOR_PANEL`), thin cyan border (`_COLOR_BORDER`), 12px content margin.
- **Labels**: Light gray text (`_COLOR_TEXT`); turn bar and stats title use accent (`_COLOR_ACCENT`); the **current turn** in the turn bar is shown in a small panel with amber border and “► TURN: P Name” / “► TURN: E Name” in amber (`_COLOR_NEXT`), larger font. The log is a RichTextLabel colored per line kind (normal, enemy, crit, absorb, miss, victory, defeat, bark).
- **Buttons**: Dark background, cyan border; slightly lighter on hover (`_make_btn_style`).
- **Progress bars**: Dark background style. HP fill is cyan, orange when low, red when critical; energy fill is yellow. Colours, tags and thresholds live in BattleFeel and are shared by the slots and the Party status panel.
- **BattlerSlot**: Its own panel style (transparent by default), HP, shield and energy bars with “HP” / “EN” tags and current/max numbers. When it’s that character’s turn, BattleScene calls `set_turn_highlight(true)` and the slot gets an amber border; otherwise the default style is restored. The selected enemy is tinted, and enemies the current attacker cannot reach are dimmed.
- **Story and menu scenes** use their own constants (`_BOX_BG`, `_BOX_BORDER`, `_NEON_CYAN`) in each script; the main menu uses green accents.

## Window and stretch

- **project.godot**: `viewport_width = 1920`, `viewport_height = 1080`, `window/stretch/mode = "canvas_items"`. The game is designed for 1920×1080; other resolutions are scaled by Godot.

For architecture and battle logic, see [ARCHITECTURE.md](ARCHITECTURE.md) and [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md).

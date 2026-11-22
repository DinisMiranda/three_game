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
| `main/main.tscn` | `scripts/main/main.gd` | Legacy: Main Control with the battle instanced as a child; not used by the game flow. |

Flow: Main menu → briefing → world map → battle (3 floors) → epilogue → hideout select → debrief → main menu. See [ARCHITECTURE.md](ARCHITECTURE.md).

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

**Start Battle** fades to black and loads `briefing_dialogue.tscn`. ESC (or **Options**) shows the options overlay, instanced in code.

## Battle scene tree

```
BattleScene (Control, battle_scene.gd)
  ├── Background (TextureRect; texture swapped per floor)
  ├── EnemyTurnFlash (ColorRect; red flash on enemy turns)
  ├── FloatingTextLayer (CanvasLayer; damage / MISS / ABSORB numbers)
  ├── Margin (MarginContainer)
  │     └── VBox (VBoxContainer)
  │           ├── FloorBanner (Label; "MERIDIAN SPIRE · Floor N — ...", hidden outside the mission)
  │           ├── TurnOrderBar (PanelContainer)
  │           │     └── TurnOrderHBox: TurnOrderLabel "Turn order:", TurnOrderList (battle_scene adds chips)
  │           ├── ArenaRow (HBoxContainer)
  │           │     ├── PartyArena: PartyLabel "Party (3)", PartySlots (VBoxContainer)
  │           │     ├── EnemyArena: EnemyLabel "Enemy", EnemySlots (VBoxContainer)
  │           │     └── PartyStatsPanel (PanelContainer): StatsTitle "Party status", StatsList (name + HP bar + HP/energy text per hero)
  │           └── BottomRow (HBoxContainer)
  │                 ├── ActionsPanel (PanelContainer)
  │                 │     └── ActionsVBox
  │                 │           ├── Buttons (HBoxContainer: AttackBtn, AbilitiesBtn)
  │                 │           ├── EndTurnRow (HBoxContainer: EndTurnBtn)
  │                 │           └── AbilitySubPanel (VBoxContainer: AbilityLabel, AbilityButtonsContainer, AbilityBackBtn)
  │                 └── LogPanel (PanelContainer; min height 220px)
  │                       └── LogScroll (ScrollContainer) → Log (RichTextLabel; newest line on top, 50 lines max)
  └── EndScreen (CanvasLayer; visible when battle ends)
        ├── Overlay (ColorRect; sized to the viewport in code)
        └── Center (CenterContainer)
              └── Panel (PanelContainer) → VBox: EndTitle, NextFloorBtn ("Ascend — next floor"), BackToMenuBtn
```

BattleManager and the options menu are **not** in the scene file; both are created in code in `battle_scene.gd` and added as children.

End screen titles: “Victory!”, “Floor clear!” (with NextFloorBtn, back button reads “Abort to menu”), “Rooftop secured!” (back button reads “Continue” and goes to the epilogue), “Meridian Spire secured!”, “Defeat!”.

## Arena formation

- **Party (left)**: One row of three slots, visual order Nova, Kael, Rin (Kael, party index 0, is in the middle).
- **Enemies (right)**: Two rows pushed right by a spacer. Enemy indices 0 and 1 are in the front row; 2 and 3, if present, in an indented back row. The Meridian Spire floors use one or two enemies.

Rows are built in `_build_arena()` with `_make_row(container, behind, add_leading_spacer, top_margin)`. When `behind == true`, the row is wrapped in a MarginContainer with `margin_left = 28`. Enemy slots are set up with a larger sprite size (380×494).

## BattlerSlot layout

```
BattlerSlot (PanelContainer, battler_slot.gd)
  └── VBox (VBoxContainer)
        ├── NameLabel
        ├── RoleLabel       (hero role, e.g. "Grenadier"; hidden when empty)
        ├── FlyingLabel     (visible when flying; "↑ Flying")
        ├── ShieldedLabel   (visible when shield active; "◇ Shielded")
        ├── GuardedLabel    (visible when guard is active)
        ├── HPBarContainer  (Control; two overlapping ProgressBars)
        │     ├── HPBar     (cyan, shows current HP)
        │     └── ShieldBar (darker blue, shows the shield amount)
        ├── EnergyBar
        └── SpriteContainer (Control; sprite area, moved up when flying)
              ├── ShieldBubble (Control + shield_bubble.gd; blue semi-transparent circle when shielded)
              └── TextureRect (sprite; 200×260 idle by default, 1.2× during attack; keep aspect centered)
```

Slots are instanced from `scenes/battle/battler_slot.tscn`. BattleScene adds each slot to the tree first, then calls `setup(stats, texture_idle, texture_attack, size_override)`. `play_attack_animation()` cycles the attack frames over 0.75s with a small scale pulse. `play_hit_flash()` tints the sprite red; `play_enemy_turn_flash()` tints the whole slot. Dead battlers’ slots are hidden by `refresh()`.

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
- **Progress bars**: Dark background style, cyan fill style (battle stats panel, and in battler_slot.gd for slot HP bars).
- **BattlerSlot**: Its own panel style (transparent by default), HP, shield and energy bars. When it’s that character’s turn, BattleScene calls `set_turn_highlight(true)` and the slot gets an amber border; otherwise the default style is restored. The selected enemy is tinted, and enemies the current attacker cannot reach are dimmed.
- **Story and menu scenes** use their own constants (`_BOX_BG`, `_BOX_BORDER`, `_NEON_CYAN`) in each script; the main menu uses green accents.

## Window and stretch

- **project.godot**: `viewport_width = 1920`, `viewport_height = 1080`, `window/stretch/mode = "canvas_items"`. The game is designed for 1920×1080; other resolutions are scaled by Godot.

For architecture and battle logic, see [ARCHITECTURE.md](ARCHITECTURE.md) and [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md).

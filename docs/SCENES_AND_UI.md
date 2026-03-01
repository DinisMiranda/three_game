# Scenes and UI

Scene tree and how the battle UI is laid out and styled.

## Main scene tree

The game starts at **MainMenu** (`scenes/main_menu/main_menu.tscn`). **Start Battle** loads the battle scene. From battle, **Back to Main Menu** (on the end screen) loads the main menu again.

```
MainMenu (Control, main_menu.gd)
  ├── Background (TextureRect; shared background image, stretch keep aspect covered)
  └── Margin / VBox: Title, StartBtn
```

When the player presses **Start Battle**, the engine loads:

```
BattleScene (Control, battle_scene.gd)
  ├── SciFiBackground, Margin (UI), EndScreen (CanvasLayer)
  └── BattleManager (created in code)
```

## Battle scene tree

```
BattleScene (Control, battle_scene.gd)
  ├── Background (TextureRect; shared background image, stretch keep aspect covered)
  └── Margin (MarginContainer, margins 32)
        └── VBox (VBoxContainer)
              ├── TurnOrderBar (PanelContainer)
              │     └── TurnOrderHBox (HBoxContainer)
              │           ├── TurnOrderLabel   "Turn order:"
              │           └── TurnOrderList     (HBoxContainer; battle_scene adds Label chips here)
              ├── ArenaRow (HBoxContainer)
              │     ├── PartyArena (VBoxContainer)
              │     │     ├── PartyLabel   "Party (3)"
              │     │     └── PartySlots   (VBoxContainer; battle_scene adds rows of BattlerSlots)
              │     ├── EnemyArena (VBoxContainer)
              │     │     ├── EnemyLabel   "Enemy"
              │     │     └── EnemySlots   (VBoxContainer; same)
              │     └── PartyStatsPanel (PanelContainer)
              │           └── StatsVBox
              │                 ├── StatsTitle   "Party status"
              │                 └── StatsList    (VBoxContainer; battle_scene adds name + bar + HP labels)
              └── BottomRow (HBoxContainer)
                    ├── ActionsPanel (PanelContainer)
                    │     └── ActionsVBox
                    │           ├── ActionsLabel
                    │           └── Buttons (HBoxContainer: AttackBtn, EndTurnBtn)
                    └── LogPanel (PanelContainer; fixed min height 220px)
                          └── LogScroll (ScrollContainer)
                                └── Log (Label; battle log, scrollable)
  └── EndScreen (CanvasLayer; visible when battle ends)
              ├── Overlay (ColorRect; full viewport)
              └── Center (CenterContainer)
                    └── Panel (Victory! / Defeat! + Back to Main Menu button)
```

BattleManager is **not** in the scene file; it is created in code in `battle_scene.gd` and added as a child of BattleScene (so it runs in the same tree but has no visual node).

## Arena formation (">" and "<")

- **Party (left)**: Two rows. **Back row** (top, indented 28px): slots for indices 0 and 1. **Front row** (bottom): slots for 2 and 3. So formation ">" (two behind, two in front).
- **Enemies (right)**: Same formation when multiple; currently the sample battle uses **one enemy** (front row, index 0).

Rows are built in `_build_arena()` with `_make_row(container, behind)`. When `behind == true`, the row is wrapped in a MarginContainer with `margin_left = 28`.

## BattlerSlot layout

```
BattlerSlot (PanelContainer, battler_slot.gd)
  └── HBox (HBoxContainer)
        ├── TextureRect   (sprite; 160×200 idle, 192×240 during attack; keep aspect centered; party/enemy use different idle textures for facing)
        └── Info (VBoxContainer)
              ├── NameLabel
              └── HPBar (ProgressBar)
```

Slots are instanced from `scenes/battle/battler_slot.tscn`. BattleScene adds each slot to the tree first, then calls `setup(stats, texture_idle, texture_attack)` with party idle (face right), enemy idle (face left), and a shared attack texture. The attack animation uses a slightly larger size (192×240) for 0.75s.

## Sci-fi theme (colors and styles)

Applied in `battle_scene.gd` (`_apply_sci_fi_theme()` and related):

- **Panels**: Dark background (`_COLOR_PANEL`), thin cyan border (`_COLOR_BORDER`), no corner radius, 12px content margin.
- **Labels**: Light gray text (`_COLOR_TEXT`); turn bar and stats title use accent (`_COLOR_ACCENT`); the **current turn** in the turn bar is shown in a small panel with amber border and “► TURN: P Name” / “► TURN: E Name” in amber (`_COLOR_NEXT`), larger font; log uses green (`_COLOR_LOG`).
- **Buttons**: Dark background, cyan border; slightly lighter on hover (`_make_btn_style`).
- **Progress bars**: Dark background style, cyan fill style (in battle scene for stats panel; in battler_slot.gd for slot HP bars).
- **BattlerSlot**: Its own panel style (dark + cyan border) and HP bar style in `_ready()`. When it’s that character’s turn, BattleScene calls `set_turn_highlight(true)` and the slot gets a thick amber border; otherwise the default style is restored.

Battle background is the fullscreen texture only (no grid overlay).

## Window and stretch

- **project.godot**: `viewport_width = 1920`, `viewport_height = 1080`, `window/stretch/mode = "canvas_items"`. So the game is designed for 1920×1080; other resolutions are scaled by Godot.

For architecture and battle logic, see [ARCHITECTURE.md](ARCHITECTURE.md) and [BATTLE_SYSTEM.md](BATTLE_SYSTEM.md).

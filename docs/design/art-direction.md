# Triad Protocol: Art Direction (Phase 2, visual coherence)

Scope: unify the existing sci-fi look. No new art. Every value below is derived from colours
already in code (`battle_scene.gd`, `battle_feel.gd`, `battler_slot.gd`, `map_zone.gd`,
`world_map_select.gd`, `main_menu.gd`) and becomes a constant in one `Theme` resource
(`assets/ui/triad_theme.tres`, name is a suggestion). Reference resolution: 1920x1080, `canvas_items` stretch.

## 1. Palette (Theme tokens)

| Token | Hex | Source today | Use |
|---|---|---|---|
| `bg_deep` | `#0A0D14` | `_COLOR_LOG_BG` | Log, bar troughs, full-screen backdrops |
| `panel_fill` | `#141720` @ 95% | `_COLOR_PANEL` | Every panel |
| `panel_raised` | `#1F242E` (hover `#2E3847`) | action button bg | Buttons, chips |
| `line_cyan` | `#00D9FF` @ 60% | `_COLOR_BORDER` | Panel/button borders |
| `accent_cyan` | `#00E5FF` | `_COLOR_ACCENT`, `hp_color`, map `_NEON_CYAN` | Focus, links, HP healthy |
| `text_primary` | `#E6EBF2` | `_COLOR_TEXT` | Body text |
| `text_secondary` | `#A6B8CC` | role label, map subtitle | Captions, roles, hints |
| `text_disabled` | `#6B7380` | (was `#808080`) | Unaffordable abilities, locked zones |
| `party_teal` | `#00D9E6` | `_COLOR_TURN_PARTY` | Party side marker, party rim light |
| `enemy_red` | `#FF6B52` | `_COLOR_TURN_ENEMY` | Enemy side marker, enemy rim light |
| `select_amber` | `#FFBF33` | `_COLOR_NEXT`, target highlight | Active turn, current selection |
| `energy_yellow` | `#FFD638` | `energy_color` | EN bars only |
| `hp_low` / `hp_crit` | `#FF9429` / `#FF423D` | `battle_feel.gd` | HP state ramp (ok = `accent_cyan`) |
| `boss_ember` | `#FF5919` | `boss_aura` glow | Boss aura only |

Semantic extras kept as-is in `battle_feel.gd` (combat text/log only, never UI chrome):
crit `#FF8C26`, absorb/shield `#73BFFF`, miss `#A6ADBF`, victory `#59FFA6`, log `#00FF8C`.
Atmosphere-only: map `neon_magenta #FF26B8` (shader background, never text or panels).

Rules: cyan = interface/party, red-amber = hostile, yellow = energy, amber = "your attention
now". One accent per screen. **Deviation to remove:** main menu green accent `#59E673`
(`main_menu.gd` `_COLOR_ACCENT`, panel border) becomes `accent_cyan` / `line_cyan`.
Known overlap: HP-healthy and party share cyan. Acceptable because HP bars sit on both sides;
side identity is carried by rim light and the turn chip, not the bar.

## 2. Typography

- **UI family: Exo 2** (SIL OFL 1.1, Google Fonts) -- **needs download** into `assets/fonts/`
  (Regular, SemiBold, Bold). Today the game uses Godot's built-in default font everywhere;
  Exo 2's squared geometry fits the sci-fi chrome without hurting legibility. Fallback if
  the download is rejected: keep Godot's default and only unify sizes.
- **Accent mono: Roboto Mono** (Apache 2.0), already in the repo at
  `addons/gdUnit4/src/update/assets/fonts/static/`. Copy Regular to `assets/fonts/`
  (do not reference the addon path; addons may be excluded from export). Replaces the
  `SystemFont` "Courier New/Consolas/Monaco" in `briefing_dialogue.gd`, `hideout_debrief.gd`,
  `meridian_epilogue.gd` -- a SystemFont renders differently per OS and on web.
- Mono is **accent only**: speaker tags, terminal headers, numeric readouts (HP 92/92).
  Briefing body text moves to Exo 2 Regular.

| Role | Size @1080p | Weight | Today |
|---|---|---|---|
| Title | 64 | Bold | menu title |
| Heading | 32 | SemiBold | end screen 36, zone title |
| Subheading / buttons | 22 | SemiBold | buttons 18-22 |
| Body | 18 | Regular | log, briefing (mono 27) |
| Dialogue | 20 | Regular | story dialogue body (briefing, epilogue, debrief); box is a centred lower panel ~56% wide x ~22% tall (`DialogueBoxStyle.BOX_ANCHORS`) |
| Caption | 14 (minimum) | Regular | role 12, turn order 13 (too small) |

Labels over the battle background get a 2 px outline `#000000` @ 85% (already used on bars).

## 3. Panel style (one StyleBoxFlat family)

- **Panel:** fill `panel_fill`, border 1 px `line_cyan`, corner radius 4, content margins
  16/12 (h/v), shadow `#000000` @ 60% size 6 (as on log history). No other panel colours.
- **Button normal:** fill `panel_raised`, border 1 px `line_cyan`, radius 4, margins 20/10.
- **hover:** fill `#2E3847`, border 1 px `accent_cyan` @ 100%.
- **pressed:** fill `bg_deep`, border 2 px `accent_cyan`, text `accent_cyan`.
- **disabled:** fill `panel_raised` @ 50%, border `text_disabled` @ 40%, text `text_disabled`.
- **focus:** no fill; 2 px `select_amber` border, expand 2 px (keyboard/gamepad visible).
- **Progress bar:** trough `bg_deep`, radius 2, height 10 (HP) / 6 (EN), fill per token;
  no border. Value text Roboto Mono 14.
- **Optional glow:** shadow colour `line_cyan` @ 25% size 8 on the *active* panel only
  (current actor's action panel). Never on all panels at once.

## 4. Character treatment

One canvas shader (`canvas_char_battler.gdshader`, to be written by technical-artist) on
every battle sprite:
- **Outline:** 2 px `#05070C` @ 90%, alpha-dilation (same technique as `boss_aura`).
- **Rim light:** 1-2 px inner edge in side colour (`party_teal` / `enemy_red`) @ 60%.
- **Grade uniforms:** `saturation`, `contrast`, `brightness` (default 1/1/0) for per-sprite fixes.
- **Scale:** visible figure height 240 px for heroes and regular enemies, 320 px for bosses,
  measured on the *trimmed* figure, not the texture. **Baseline:** feet on a shared floor line
  (slot bottom minus 8 px), not vertically centred (`STRETCH_KEEP_ASPECT_CENTERED` today
  centres, so padded sprites float and shrink).
- Boss keeps `boss_aura` (it replaces the outline/rim for that slot).
- Enemy sprites (`enemy_1-removebg-preview.png`, `inimigo_soldado.png`) carry a baked
  ground base. Align the **base bottom** to the floor line; flag as known inconsistency.

**Kael fix** (`assets/sevro_pixel_no_bg-removebg-preview.png`): the art is a low-res pixel
sprite upscaled with blur, near-monochrome blue-grey (only accent: a tiny yellow eye), cut out
with remove.bg's low-res preview tier, and has large transparent padding (top ~20%, crouched
pose). Against the blue-lit backgrounds it reads grey; inside a 200x260 keep-aspect box it
renders ~25% shorter than Nova/Rin. Fix without new art:
1. Trim the padding (AtlasTexture region or a trimmed re-save) so scale rules apply to the figure.
2. Grade in the shader: saturation 1.4, contrast 1.25, brightness -0.08 (pull its mids down
   to the dark-armour value range of Nova/Rin).
3. Rim light + outline do the rest of the separation.
Honest limit: it will still be the softest sprite. It is the first candidate for a free-pack
replacement under the Art direction rule in `portfolio-plan.md`, and the README labels it placeholder.

## 5. Screen notes

- **Main menu:** empty "ABOUT THE GAME / Placeholder" panel becomes a teaser: three hero
  portraits with name + role, one-line mission hook, current floor. "Start Battle" becomes
  "Continue" (primary, when a save exists) + "New Mission". Subtitle "Turn-based battle" ->
  a mission tagline. Accent to cyan. `menu_bg_repeat` shows a visible seam at ~x=1535; fix the tiling.
- **Tactical map:** replace the flat grey bars with the shared panel; deploy button uses the
  shared button styles (drop its local `#0D1F29` style). Zones: unlocked = `line_cyan` border +
  `accent_cyan` 14% fill; **hover** = `accent_cyan` border 2 px + 22% fill + label to
  `text_primary`; locked = `text_disabled`. `map_zone.gd` already has `_FILL_HOVER` (teal-green
  `#00FFD9`): retint to `accent_cyan`.
- **Battle (closest to spec), deviations:** turn-order label 13 and role label 12 -> 14;
  name labels over busy backgrounds (Rin over the hologram) need the outline; slot selection
  box is a hard amber rectangle -- use the focus style with radius 4; "Party (3)"/"Enemy"
  headers float with no panel; log text green `#00FF8C` is a fourth accent -- keep for log
  only; dead-sprite modulate and button overrides move to Theme.

## 6. Renderer note (Compatibility for web)

`project.godot` sets no `rendering_method`, so desktop runs Forward+ today. Under Compatibility:
- **Over-bright modulates** (`hit_flash_color` 3.0, slot `Color(1.2,1.2,1.0)`, turn flash 1.25)
  clamp at 1.0 without HDR 2D; flashes will look weaker. Re-tune by eye in a web build.
- **`boss_aura.gdshader`:** 16 texture reads in a loop per fragment; works on WebGL2 but is the
  most expensive 2D shader. Check frame time on a low-end laptop browser.
- **`map_select_atmosphere.gdshader`:** `sin(uv.y * 900.0)` scanlines alias/moire at non-1080p
  canvas sizes; `sin(TIME * 37.0)` flicker loses precision in long sessions. Verify both.
- **`menu_bg.gdshader` / `menu_bg_repeat.gdshader`:** scroll relies on texture repeat being enabled
  on the node; confirm in the web export.
No WorldEnvironment/glow is used, so nothing else is lost.

## 7. Credits (for CREDITS.md)

- Roboto Mono -- Google, Apache 2.0 (bundled with gdUnit4).
- Exo 2 -- Natanael Gama, SIL OFL 1.1 (once downloaded).
- gdUnit4 -- MIT (test addon; not shipped in export).
- Music `assets/music/background.mp3` -- **UNKNOWN** source/licence.
- All character sprites, enemy sprites, backgrounds (`andar.jpg`, `alley.png`,
  `background_blue.png`, `escritorio.png`, `mapa.png`, the hash-named rooftop PNG), menu
  city art -- **UNKNOWN** source/licence. Must be resolved before the itch.io release.

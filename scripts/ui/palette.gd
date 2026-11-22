class_name Palette
extends RefCounted
## Triad Protocol palette tokens (docs/design/art-direction.md §1).
##
## Code that must set a colour at runtime uses these tokens, never literals.
## Chrome (panels, buttons, labels, bars) is styled by the Theme
## (assets/ui/triad_theme.tres, built by TriadThemeBuilder), which reads the
## same tokens. Combat-text and log semantic colours stay in BattleFeel.

## Log, bar troughs, full-screen backdrops.
const BG_DEEP := Color("#0A0D14")
## Every panel (#141720 @ 95%).
const PANEL_FILL := Color("#141720F2")
## Buttons, chips.
const PANEL_RAISED := Color("#1F242E")
## Button hover fill.
const PANEL_HOVER := Color("#2E3847")
## Panel and button borders (#00D9FF @ 60%).
const LINE_CYAN := Color("#00D9FF99")
## Focus, links, HP healthy, the one interface accent.
const ACCENT_CYAN := Color("#00E5FF")
## Body text.
const TEXT_PRIMARY := Color("#E6EBF2")
## Captions, roles, hints.
const TEXT_SECONDARY := Color("#A6B8CC")
## Unaffordable abilities, locked zones.
const TEXT_DISABLED := Color("#6B7380")
## Party side marker, party rim light.
const PARTY_TEAL := Color("#00D9E6")
## Enemy side marker, enemy rim light.
const ENEMY_RED := Color("#FF6B52")
## Active turn, current selection, keyboard focus.
const SELECT_AMBER := Color("#FFBF33")
## EN bars only.
const ENERGY_YELLOW := Color("#FFD638")
## HP at or below the low threshold.
const HP_LOW := Color("#FF9429")
## HP at or below the critical threshold.
const HP_CRIT := Color("#FF423D")
## Boss aura only.
const BOSS_EMBER := Color("#FF5919")
## Panel drop shadow (#000000 @ 60%).
const SHADOW := Color("#00000099")
## Label outline over busy backgrounds (#000000 @ 85%).
const OUTLINE := Color("#000000D9")


## Returns [param color] with its alpha replaced by [param alpha].
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

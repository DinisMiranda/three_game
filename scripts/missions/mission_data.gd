class_name MissionData
extends Resource
## A multi-floor mission (Phase 3B), e.g. resources/missions/meridian_spire.tres.
## MissionProgress reads its floors; floor 1 is floors[0].

## Stable mission id, e.g. "meridian_spire".
@export var id: String = ""
## Mission name shown on the map / menu.
@export var display_name: String = ""
## Floors in climb order (the last one is the rooftop / boss floor).
@export var floors: Array[FloorData] = []
## Share of each hero's max HP recovered between floors (energy always refills).
## 1.0 = full heal. Rebalance v2 sets Meridian Spire to 0.25 so the climb is an
## attrition run: see docs/design/rebalance-v2.md.
@export_range(0.0, 1.0, 0.05) var between_floor_hp_restore: float = 1.0

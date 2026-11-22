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

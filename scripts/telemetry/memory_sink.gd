extends TelemetrySink
class_name TelemetryMemorySink
## In-memory [TelemetrySink] for tests and in-process analysis (no file I/O).

## Accepted events, in emission order.
var events: Array[Dictionary] = []
## Their JSON lines, in emission order.
var lines: PackedStringArray = PackedStringArray()
## Number of [method flush] calls, so tests can assert flush points.
var flush_count: int = 0


func write_event(event: Dictionary, line: String) -> void:
	events.append(event)
	lines.append(line)


func flush() -> void:
	flush_count += 1


## Event names in order, e.g. ["battle_start", "turn_start", "action", ...].
func names() -> PackedStringArray:
	var out := PackedStringArray()
	for e in events:
		out.append(str(e.get("event_name", "")))
	return out


## Events whose event_name is [param event_name].
func of(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e.get("event_name", "") == event_name:
			out.append(e)
	return out


func clear() -> void:
	events.clear()
	lines.clear()
	flush_count = 0

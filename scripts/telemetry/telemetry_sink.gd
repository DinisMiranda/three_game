extends RefCounted
class_name TelemetrySink
## Destination for serialised telemetry events (dependency-injection seam).
##
## [TelemetryService] validates and serialises; a sink only stores. Swap the sink
## to redirect output: [TelemetryFileSink] for players and the simulator,
## [TelemetryMemorySink] for tests. Subclasses override all three methods.


## Accepts one validated event. [param event] is the envelope Dictionary and
## [param line] its JSON serialisation (no trailing newline).
func write_event(_event: Dictionary, _line: String) -> void:
	pass


## Persists anything buffered. Safe to call when there is nothing to flush.
func flush() -> void:
	pass


## Flushes and releases resources. The sink may not be used afterwards.
func close() -> void:
	flush()

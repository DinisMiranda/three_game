extends TelemetrySink
class_name TelemetryFileSink
## Buffered JSON Lines [TelemetrySink]: appends to
## [code]<dir>/<prefix>_YYYY-MM-DD.jsonl[/code] (UTC date) and rotates to
## [code]_1[/code], [code]_2[/code]... once a file reaches [member max_bytes].

const DEFAULT_MAX_BYTES := 5 * 1024 * 1024
const DEFAULT_BUFFER_LINES := 64

var directory: String
var prefix: String
var max_bytes: int
## Auto-flush threshold; [TelemetryService] also flushes on battle end, scene change and quit.
var buffer_lines: int
## False = no date in the file name ([code]<dir>/<prefix>.jsonl[/code]); the simulator names its own files.
var dated: bool = true
var _buffer: PackedStringArray = PackedStringArray()


func _init(dir_path: String = "user://telemetry", file_prefix: String = "events", max_file_bytes: int = DEFAULT_MAX_BYTES, buffer_size: int = DEFAULT_BUFFER_LINES) -> void:
	directory = dir_path
	prefix = file_prefix
	max_bytes = max_file_bytes
	buffer_lines = maxi(1, buffer_size)


func write_event(_event: Dictionary, line: String) -> void:
	_buffer.append(line)
	if _buffer.size() >= buffer_lines:
		flush()


func pending_lines() -> int:
	return _buffer.size()


func flush() -> void:
	if _buffer.is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK and not DirAccess.dir_exists_absolute(directory):
		push_warning("TelemetryFileSink: cannot create %s; dropping %d lines" % [directory, _buffer.size()])
		_buffer.clear()
		return
	var path := current_path()
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("TelemetryFileSink: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		_buffer.clear()
		return
	f.seek_end()
	for line in _buffer:
		f.store_string(line + "\n")
	f.close()
	_buffer.clear()


## File the next flush appends to: today's base file, or the first rotation
## suffix whose file is still under [member max_bytes].
func current_path() -> String:
	var base := "%s/%s" % [directory, prefix]
	if dated:
		base += "_" + Time.get_date_string_from_system(true)
	var path := base + ".jsonl"
	var n := 0
	# max_bytes <= 0 disables rotation.
	while max_bytes > 0 and FileAccess.file_exists(path) and _file_size(path) >= max_bytes:
		n += 1
		path = "%s_%d.jsonl" % [base, n]
	return path


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size

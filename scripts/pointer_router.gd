extends RefCounted
## One logical gesture from touch, pointer or mouse; mouse-only is valid too.
## Cross-source duplicates match a completed gesture, never a whole device.
const DUPLICATE_MS := 500
const DUPLICATE_DISTANCE := 24.0
var source := ""
var pointer_id := -1
var last_source := ""
var last_position := Vector2.ZERO
var last_finished := -1000
var ignored: Dictionary = {}

func cancel() -> void:
	source = ""
	pointer_id = -1
	last_source = ""
	last_finished = -1000
	ignored.clear()

func feed(phase: String, position: Vector2, origin: String, id: int = 0, now: int = -1) -> String:
	if now < 0:
		now = Time.get_ticks_msec()
	var key := "%s:%d" % [origin, id]
	if phase == "down":
		if not source.is_empty():
			if origin != source or id != pointer_id:
				ignored[key] = true
			return ""
		if origin != last_source and not last_source.is_empty() and now - last_finished < DUPLICATE_MS and position.distance_to(last_position) < DUPLICATE_DISTANCE:
			ignored[key] = true
			return ""
		ignored.erase(key)
		source = origin
		pointer_id = id
		return "down"
	if ignored.has(key):
		if phase in ["up", "cancel"]:
			ignored.erase(key)
			# A native touch can arrive after a completed emulated mouse click.
			# Prefer it for the next tap, so rapid real taps are never debounced.
			if phase == "up" and source.is_empty() and origin == "touch" and last_source in ["mouse", "mouse-emulated"]:
				last_source = "touch"
		return ""
	if phase == "move":
		return "move" if (origin == source and id == pointer_id) or (source.is_empty() and origin in ["mouse", "mouse-emulated", "pointer-mouse"]) else ""
	if origin != source or id != pointer_id:
		return ""
	if phase in ["up", "cancel"]:
		last_source = source
		last_position = position
		last_finished = now
		source = ""
		pointer_id = -1
		return phase
	return ""

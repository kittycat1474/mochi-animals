extends RefCounted
## Replace request() with an ad SDK later; complete only on earned-reward,
## never on ad close/cancel/failure. Each request may complete at most once.
signal completed(placement: String, request_id: int)
const TEST_REWARDS := true
var next_id := 0
var pending_id := -1
var pending_placement := ""

func request(placement: String) -> int:
	if pending_id != -1 or placement not in ["gift", "revive"]:
		return -1
	next_id += 1
	var id := next_id
	pending_id = id
	pending_placement = placement
	if TEST_REWARDS:
		complete(id, true)
	return id

func complete(id: int, earned: bool) -> void:
	if id != pending_id or id < 0:
		return
	var placement := pending_placement
	pending_id = -1
	pending_placement = ""
	if earned:
		completed.emit(placement, id)

func cancel() -> void:
	pending_id = -1
	pending_placement = ""

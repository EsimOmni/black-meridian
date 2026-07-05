extends Camera3D
## Skyline / establishing camera (P12b). A SECOND, non-gameplay camera that presents the district
## from the master keyframe's cinematic 3/4 diorama angle (docs/prompts/notes/concept/
## glass_wharf_MASTER.jpg) — the hero landmarks read at their intended composition. The management
## camera (brief §9.2 near-ortho top-down) stays untouched; this is a pure presentation view,
## toggled with C. It holds a fixed transform: no pan, no zoom, no state.

## Framed to hold the venue row (x∈[-20,20], z≈0) AND the alien tower landmark (right-rear,
## out toward the water) in one shot, echoing the master's high 3/4 read.
const EYE := Vector3(10.0, 44.0, 52.0)    # high, pulled back, biased right toward the landmark
const LOOK := Vector3(8.0, 10.0, -16.0)   # aim between the row and the deep right-rear tower

func _ready() -> void:
	position = EYE
	look_at(LOOK, Vector3.UP)
	fov = 60.0  # tighter than the top-down management read — a cinematic diorama framing
	current = false

class_name SplatWorldProvider
extends RefCounted
## The GDGS splat route behind the CinematicWorldProvider contract — the proven P01
## path (SPLAT_OK, 542k @ 483 fps), lifted verbatim from the P17b scene code. Kept as
## the swap target for a future captured splat world; not the ship-first default.

const SPLAT_PATH := "res://assets/splat/bench_542k.ply"

static func build(parent: Node3D) -> Dictionary:
	var out := {"center": Vector3.ZERO, "floor_y": 0.0, "bounds_half": 2.0}
	var res: Resource = load(SPLAT_PATH)
	if res == null:
		printerr("SplatWorldProvider: could not load %s — greybox only" % SPLAT_PATH)
		return out
	var splat := GaussianSplatNode.new()
	splat.gaussian = res
	parent.add_child(splat)
	var effect_script := load("res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd")
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect_script.new()]
	var env := WorldEnvironment.new()
	env.compositor = compositor
	parent.add_child(env)
	var aabb: AABB = res.aabb
	var center: Vector3 = aabb.get_center()
	out["center"] = center
	out["floor_y"] = center.y - 0.8
	return out

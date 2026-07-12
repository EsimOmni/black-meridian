class_name CinematicWorldProvider
extends RefCounted
## P17 (lite) — the cinematic-world seam (brief §7.7, §14): the P01 deferred debt, paid.
## A cinematic scene never builds its own world; it asks this provider, and the provider
## decides WHICH world technique backs the sequence. Ship-first default = the $0 mesh
## interior (MeshWorldProvider — kit-material back-room from code + existing props).
## The splat route (SplatWorldProvider — GDGS, SPLAT_OK per P01) stays behind the same
## contract, so swapping the whole cinematic layer to a captured splat world later is a
## one-line flip here — exactly the swappability the kill-criterion demanded.
##
## Contract: build(parent) adds the world's nodes under parent and returns
##   { "center": Vector3, "floor_y": float, "bounds_half": float }
## center   = where the sequence's actors/camera anchor
## floor_y  = the walkable plane height
## bounds_half = half-extent of the hard walk clamp around center

const USE_SPLAT := false  ## flip to route cinematics back onto the GDGS splat world

static func build(parent: Node3D) -> Dictionary:
	if USE_SPLAT:
		return SplatWorldProvider.build(parent)
	return MeshWorldProvider.build(parent)

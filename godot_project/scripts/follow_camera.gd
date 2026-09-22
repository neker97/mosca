extends Camera3D

@export var min_distance: float = 6.0
@export var max_distance: float = 22.0
@export var height_ratio: float = 0.65
@export var padding: float = 5.0

@onready var arena: Node3D = get_parent()


func _process(_delta: float) -> void:
	var a: Fly = arena.fly_a
	var b: Fly = arena.fly_b
	if a == null or b == null:
		return
	var mid := (a.global_position + b.global_position) / 2.0
	var sep := a.global_position.distance_to(b.global_position)
	var dist := clampf(sep + padding, min_distance, max_distance)
	global_position = mid + Vector3(0, dist * height_ratio, dist)
	look_at(mid, Vector3.UP)

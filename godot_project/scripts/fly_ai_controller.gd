extends AIController3D

@onready var fly: Fly = get_parent()


func get_obs() -> Dictionary:
	var opp := fly.opponent
	var rel := Vector3.ZERO
	var dist := 0.0
	var opp_hp := 0.0
	if opp:
		rel = (opp.global_position - fly.global_position).normalized()
		dist = fly.global_position.distance_to(opp.global_position)
		opp_hp = opp.hp
	return {
		"obs": [
			dist / fly.loom_detect_radius,
			rel.x,
			rel.z,
			fly.cooldown_left / fly.throw_cooldown,
			fly.hp,
			opp_hp,
		]
	}


func get_reward() -> float:
	var r := fly.consume_reward()
	reward += r
	return reward


func get_action_space() -> Dictionary:
	return {
		"move": {"size": 2, "action_type": "continuous"},
		"throw": {"size": 2, "action_type": "discrete"},
	}


func set_action(action) -> void:
	fly.set_move_action(Vector2(action["move"][0], action["move"][1]))
	fly.set_throw_action(action["throw"] == 1)

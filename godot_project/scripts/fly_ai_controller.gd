extends AIController3D

const APPROACH_SHAPING_COEF := 0.05  # premio denso per avvicinarsi: fa emergere segnale per la value function

@onready var fly: Fly = get_parent()

var _prev_dist: float = -1.0

# ultimi valori osservati/agiti, letti dall'HUD di debug (hud.gd) per mostrare
# cosa "vede" la rete e come reagisce, invece di fidarsi che sia RL sulla fiducia
var last_obs: Array = []
var last_move_action: Vector2 = Vector2.ZERO
var last_throw_action: bool = false


func reset():
	super.reset()
	_prev_dist = -1.0


func get_obs() -> Dictionary:
	var opp := fly.opponent
	var rel := Vector3.ZERO
	var dist := 0.0
	var opp_hp := 0.0
	if opp:
		rel = (opp.global_position - fly.global_position).normalized()
		dist = fly.global_position.distance_to(opp.global_position)
		opp_hp = opp.hp
	last_obs = [
		dist / fly.loom_detect_radius,
		rel.x,
		rel.z,
		fly.cooldown_left / fly.throw_cooldown,
		fly.hp,
		opp_hp,
	]
	return {"obs": last_obs}


func get_reward() -> float:
	var r := fly.consume_reward()
	reward += r

	if fly.opponent:
		var dist := fly.global_position.distance_to(fly.opponent.global_position)
		if _prev_dist >= 0.0:
			# reward shaping denso: avvicinarsi al nemico da' un piccolo bonus
			# continuo, cosi' la value function ha un segnale su cui imparare
			# invece del solo colpo/vittoria (troppo sparso, vedi docs/current-work.md)
			reward += APPROACH_SHAPING_COEF * (_prev_dist - dist)
		_prev_dist = dist

	return reward


func get_action_space() -> Dictionary:
	return {
		"move": {"size": 2, "action_type": "continuous"},
		"throw": {"size": 2, "action_type": "discrete"},
	}


func set_action(action) -> void:
	last_move_action = Vector2(action["move"][0], action["move"][1])
	last_throw_action = action["throw"] == 1
	fly.set_move_action(last_move_action)
	fly.set_throw_action(last_throw_action)

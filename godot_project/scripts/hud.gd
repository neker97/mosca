extends CanvasLayer

@onready var arena: Node3D = get_parent()
@onready var label_a: Label = $MarginContainer/HBoxContainer/PanelA/LabelA
@onready var label_b: Label = $MarginContainer/HBoxContainer/PanelB/LabelB


func _process(_delta: float) -> void:
	label_a.text = _fly_debug_text("A", arena.fly_a, arena.score_a)
	label_b.text = _fly_debug_text("B", arena.fly_b, arena.score_b)


func _fly_debug_text(tag: String, fly: Fly, score: int) -> String:
	var ctrl: AIController3D = fly.get_node("AIController")
	var obs: Array = ctrl.last_obs
	var obs_str := "n/d"
	if obs.size() == 6:
		obs_str = "dist=%.2f dir=(%.2f,%.2f) cd=%.2f hp=%.2f opp_hp=%.2f" % [
			obs[0], obs[1], obs[2], obs[3], obs[4], obs[5]
		]
	var action_str := "move=(%.2f,%.2f) lancia=%s" % [
		ctrl.last_move_action.x, ctrl.last_move_action.y, "SI" if ctrl.last_throw_action else "no"
	]
	return "MOSCA %s  |  punteggio %d\nHP: %.0f%%\nvede: %s\nfa: %s" % [
		tag, score, fly.hp * 100.0, obs_str, action_str
	]

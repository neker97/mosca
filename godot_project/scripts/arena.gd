extends Node3D

@onready var fly_a: Fly = $FlyA
@onready var fly_b: Fly = $FlyB

var start_pos_a: Vector3
var start_pos_b: Vector3


func _ready() -> void:
	fly_a.opponent = fly_b
	fly_b.opponent = fly_a
	start_pos_a = fly_a.global_position
	start_pos_b = fly_b.global_position


func _physics_process(_delta: float) -> void:
	if fly_a.hp <= 0.0 or fly_b.hp <= 0.0:
		_end_round()


func _end_round() -> void:
	var ctrl_a: AIController3D = fly_a.get_node("AIController")
	var ctrl_b: AIController3D = fly_b.get_node("AIController")
	if fly_a.hp <= 0.0:
		ctrl_a.reward -= 10.0
		ctrl_b.reward += 10.0
	else:
		ctrl_b.reward -= 10.0
		ctrl_a.reward += 10.0
	ctrl_a.done = true
	ctrl_b.done = true

	fly_a.global_position = start_pos_a
	fly_b.global_position = start_pos_b
	fly_a.reset_state()
	fly_b.reset_state()

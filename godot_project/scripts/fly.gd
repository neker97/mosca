extends CharacterBody3D
class_name Fly

@export var move_speed: float = 6.0
@export var dodge_speed: float = 10.0
@export var throw_cooldown: float = 1.0
@export var max_hp: float = 1.0
@export var loom_detect_radius: float = 8.0
@export var loom_dodge_speed_threshold: float = 4.0  # closing speed that triggers reflex dodge
@export var preferred_distance: float = 4.0  # usata solo in modalita' autonoma
@export var throw_range: float = 6.0  # usata solo in modalita' autonoma

var hp: float = max_hp
var opponent: Fly
var cooldown_left: float = 0.0
var last_hit_reward: float = 0.0  # read/cleared by AIController each step
var autonomous: bool = false  # true quando nessun server RL e' connesso (demo alpha)

var _move_action := Vector2.ZERO
var _throw_action := false

const FIREBALL_SCENE := preload("res://scenes/fireball.tscn")

@onready var fireball_spawn: Node3D = $FireballSpawn


func _physics_process(delta: float) -> void:
	cooldown_left = max(0.0, cooldown_left - delta)

	if autonomous:
		_run_autonomous_heuristic()

	var dodge_dir := _reflex_dodge_direction()
	if dodge_dir != Vector3.ZERO:
		# riflesso ha priorita' sull'azione RL/euristica quando c'e' pericolo imminente
		velocity.x = dodge_dir.x * dodge_speed
		velocity.z = dodge_dir.z * dodge_speed
	else:
		velocity.x = _move_action.x * move_speed
		velocity.z = _move_action.y * move_speed

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if _throw_action and cooldown_left <= 0.0:
		_throw()

	_throw_action = false


func _run_autonomous_heuristic() -> void:
	# demo alpha: nessun server RL connesso, comportamento scriptato semplice
	if opponent == null:
		_move_action = Vector2.ZERO
		_throw_action = false
		return
	var to_opp: Vector3 = opponent.global_position - global_position
	var dist := to_opp.length()
	var dir2d := Vector2(to_opp.x, to_opp.z).normalized()

	if dist > preferred_distance + 0.5:
		_move_action = dir2d
	elif dist < preferred_distance - 0.5:
		_move_action = -dir2d
	else:
		_move_action = Vector2.ZERO

	_throw_action = dist <= throw_range and cooldown_left <= 0.0


func _reflex_dodge_direction() -> Vector3:
	# loom-detection: cerca proiettili nemici in avvicinamento rapido entro raggio
	for fb in get_tree().get_nodes_in_group("fireball"):
		if fb.shooter == self:
			continue
		var to_fly: Vector3 = global_position - fb.global_position
		var dist := to_fly.length()
		if dist > loom_detect_radius:
			continue
		var closing_speed: float = -fb.linear_velocity.dot(to_fly.normalized())
		if closing_speed > loom_dodge_speed_threshold:
			# schiva laterale, perpendicolare alla traiettoria del proiettile
			var perp := Vector3(-fb.linear_velocity.z, 0.0, fb.linear_velocity.x).normalized()
			return perp
	return Vector3.ZERO


func set_move_action(v: Vector2) -> void:
	_move_action = v


func set_throw_action(b: bool) -> void:
	_throw_action = b


func _throw() -> void:
	if opponent == null:
		return
	cooldown_left = throw_cooldown
	var fb := FIREBALL_SCENE.instantiate()
	get_tree().current_scene.add_child(fb)
	fb.global_position = fireball_spawn.global_position
	fb.shooter = self
	var dir := (opponent.global_position - fireball_spawn.global_position).normalized()
	fb.launch(dir)


func take_damage(amount: float) -> void:
	hp = max(0.0, hp - amount)
	last_hit_reward -= amount


func register_hit_dealt(amount: float) -> void:
	last_hit_reward += amount


func consume_reward() -> float:
	var r := last_hit_reward
	last_hit_reward = 0.0
	return r


func reset_state() -> void:
	hp = max_hp
	cooldown_left = 0.0
	last_hit_reward = 0.0
